RSpec.describe VmScan do
  context "A single VM Scan Job," do
    let(:server) { EvmSpecHelper.local_miq_server(:has_vix_disk_lib => true) }
    let(:user) { FactoryBot.create(:user_with_group, :userid => "tester") }
    let(:ems) { FactoryBot.create(:ems_infra, :zone => server.zone) }
    let(:vm) { FactoryBot.create(:vm_infra, :ext_management_system => ems, :host => host, :miq_group => user.current_group, :evm_owner => user) }
    let(:host) { FactoryBot.create(:host, :ext_management_system => ems) }
    let(:job) { described_class.first }

    describe "#scan" do
      before do
        allow(MiqEventDefinition).to receive_messages(:find_by => true)
        allow(server).to receive(:has_active_role?).with('automate').and_return(true)

        vm.scan

        job_item = MiqQueue.find_by(:class_name => "MiqAeEngine", :method_name => "deliver")
        job_item.delivered(*job_item.deliver)

        # Allow the use of allow(job) and expect(job) instead of having to use
        # [allow/expect]_any_instance_of(VmScan) due to some signals being
        # queued.
        allow(Job).to receive(:find).with(job.id).and_return(job)
      end

      it "should start in a state of waiting_to_start" do
        expect(job.state).to eq("waiting_to_start")
      end

      context "waiting_to_start" do
        before { job.update!(:state => "waiting_to_start") }

        it "#start should transit to state checking_policy" do
          job.signal(:start)
          expect(job.reload.state).to eq("checking_policy")
        end

        it "#start should call before_start after checking policy" do
          job.signal(:start)

          # check_policy raises an miq_event, deliver the raise_evm_job_event
          job_item = MiqQueue.find_by(:class_name => "MiqAeEngine", :method_name => "deliver")
          job_item.delivered(*job_item.deliver)

          expect(job).to receive(:before_scan)

          # Then deliver the signal from that event
          queue_item = MiqQueue.find_by(:class_name => job.class.name, :method_name => "signal")
          queue_item.delivered(*queue_item.deliver)
        end
      end

      context "checking_policy" do
        before { job.update!(:state => "checking_policy") }

        it "#before_scan should transit to state before_scan" do
          allow(job).to receive(:before_scan)

          job.signal(:before_scan)
          expect(job.reload.state).to eq("before_scan")
        end

        it "#before_scan should call start_scan" do
          expect(job).to receive(:start_scan)

          job.signal(:before_scan)
          expect(job.reload.state).to eq("scanning")
        end
      end

      context "scanning" do
        before { job.update!(:state => "scanning") }

        it "#after_scan transits to state after_scan" do
          allow(job).to receive(:after_scan)

          job.signal(:after_scan)
          expect(job.reload.state).to eq("after_scan")
        end

        it "#data should call process_data and stay in state scanning" do
          expect(job).to receive(:process_data)

          job.signal(:data)
          expect(job.reload.state).to eq("scanning")
        end

        it "#after_scan should call synchronize" do
          expect(job).to receive(:synchronize)
          job.signal(:after_scan)
        end
      end

      context "synchronizing" do
        before { job.update!(:state => "synchronizing") }

        it "#finish from process_data transits to state finished" do
          job.signal(:finish)
          expect(job.reload.state).to eq("finished")
        end
      end
    end
  end

  # test cases for BZ #1454936
  context "A VM Scan job in multiple zones" do
    before do
      # local zone
      @server1 = EvmSpecHelper.local_miq_server(:has_vix_disk_lib => true)
      @user      = FactoryBot.create(:user_with_group, :userid => "tester")
      @ems       = FactoryBot.create(:ems_vmware_with_authentication, :name   => "Test EMS", :zone => @server1.zone,
                                      :tenant                                  => FactoryBot.create(:tenant))
      @storage   = FactoryBot.create(:storage, :name => "test_storage", :store_type => "VMFS")
      @host      = FactoryBot.create(:host, :name => "test_host", :hostname => "test_host",
                                      :state       => 'on', :ext_management_system => @ems)
      @vm        = FactoryBot.create(:vm_vmware, :name => "test_vm", :location => "abc/abc.vmx",
                                      :raw_power_state       => 'poweredOn',
                                      :host                  => @host,
                                      :ext_management_system => @ems,
                                      :miq_group             => @user.current_group,
                                      :evm_owner             => @user,
                                      :storage               => @storage)

      # remote zone
      @server2 = EvmSpecHelper.remote_miq_server(:has_vix_disk_lib => true)
      @user2     = FactoryBot.create(:user_with_group, :userid => "tester2")
      @storage2  = FactoryBot.create(:storage, :name => "test_storage2", :store_type => "VMFS")
      @host2     = FactoryBot.create(:host, :name => "test_host2", :hostname => "test_host2",
                                      :state       => 'on', :ext_management_system => @ems)
      @vm2       = FactoryBot.create(:vm_vmware, :name => "test_vm2", :location => "abc2/abc2.vmx",
                                      :raw_power_state       => 'poweredOn',
                                      :host                  => @host2,
                                      :ext_management_system => @ems,
                                      :miq_group             => @user2.current_group,
                                      :evm_owner             => @user2,
                                      :storage               => @storage2)

      allow(MiqEventDefinition).to receive_messages(:find_by => true)
      allow(@server1).to receive(:has_active_role?).with('automate').and_return(true) # set automate role in local zone
    end

    describe "#check_policy_complete" do
      context "in local zone" do
        before do
          @vm.scan
          job_item = MiqQueue.find_by(:class_name => "MiqAeEngine", :method_name => "deliver")
          job_item.delivered(*job_item.deliver)

          @job = Job.first
        end

        it "signals :abort if passed status is not 'ok' to local zone" do
          message = "Hello, World!"
          expect(@job).to receive(:signal).with(:abort, message, "error")
          @job.check_policy_complete(@server1.my_zone, 'some status', message, nil)
        end

        it "does not send signal :abort if passed status is 'ok' " do
          expect(@job).not_to receive(:signal).with(:abort, nil, "error")
          @job.check_policy_complete(@server1.my_zone, 'ok', nil, nil)
        end

        it "sends signal :before_scan if status is 'ok' to local zone" do
          expect(MiqQueue).to receive(:put).with(
            :class_name  => @job.class.to_s,
            :instance_id => @job.id,
            :method_name => "signal",
            :args        => [:before_scan],
            :zone        => @server1.my_zone,
            :role        => "smartstate"
          )
          @job.check_policy_complete(@server1.my_zone, 'ok', nil, nil)
        end
      end

      context "in remote zone" do
        before do
          @vm2.scan
          job_item = MiqQueue.find_by(:class_name => "MiqAeEngine", :method_name => "deliver")
          job_item.delivered(*job_item.deliver)

          @job = Job.first
        end
        it "signals :abort if status is not 'ok' to remote zone" do
          message = "Hello, World!"
          expect(@job).to receive(:signal).with(:abort, message, "error")
          @job.check_policy_complete(@server2.my_zone, 'some status', message, nil)
        end

        it "does not send signal :abort if passed status is 'ok' " do
          expect(@job).not_to receive(:signal).with(:abort, nil, "error")
          @job.check_policy_complete(@server2.my_zone, 'ok', nil, nil)
        end

        it "signals :before_scan if status is 'ok' to remote zone" do
          expect(MiqQueue).to receive(:put).with(
            :class_name  => @job.class.to_s,
            :instance_id => @job.id,
            :method_name => "signal",
            :args        => [:before_scan],
            :zone        => @server2.my_zone,
            :role        => "smartstate"
          )
          @job.check_policy_complete(@server2.my_zone, 'ok', nil, nil)
        end
      end
    end
  end
end
