describe VmScan do
  context "A single VM Scan Job on VMware provider," do
    before do
      @server = EvmSpecHelper.local_miq_server(:capabilities => {:vixDisk => true})
      assign_smartproxy_role_to_server(@server)

      # TODO: stub only settings needed for test instead of all from settings.yml
      stub_settings(::Settings.to_hash.merge(:coresident_miqproxy => {:scan_via_host => false}))

      @user      = FactoryBot.create(:user_with_group, :userid => "tester")
      @ems       = FactoryBot.create(:ems_vmware_with_authentication, :name   => "Test EMS", :zone => @server.zone,
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
                                      :storage               => @storage
                                     )

      allow(MiqEventDefinition).to receive_messages(:find_by => true)
      @ems.authentication_type(:default).update_attribute(:status, "Valid")
      @vm.scan
      job_item = MiqQueue.find_by(:class_name => "MiqAeEngine", :method_name => "deliver")
      job_item.delivered(*job_item.deliver)

      @job = Job.first
    end

    it "should start in a state of waiting_to_start" do
      expect(@job.state).to eq("waiting_to_start")
    end

    it "should start in a dispatch_status of pending" do
      expect(@job.dispatch_status).to eq("pending")
    end

    it "should respond properly to proxies4job" do
      expect(@vm.proxies4job[:message]).to eq("Perform SmartState Analysis on this VM")
    end

    it "should respond properly to storage2hosts" do
      expect(@vm.storage2hosts).to eq([@host])
    end

    context "without MiqVimBrokerWorker record," do
      it "should not be dispatched" do
        JobProxyDispatcher.dispatch
        @job.reload
        expect(@job.state).to eq("waiting_to_start")
        expect(@job.dispatch_status).to eq("pending")
      end
    end

    context "without Broker Running and with valid MiqVimBrokerWorker record," do
      before do
        @vim_broker_worker = FactoryBot.create(:miq_vim_broker_worker, :miq_server_id => @server.id)
      end

      context "in status of 'starting'," do
        before do
          @vim_broker_worker.update(:status => 'starting')
        end

        it "should not be dispatched" do
          JobProxyDispatcher.dispatch
          @job.reload
          expect(@job.state).to eq("waiting_to_start")
          expect(@job.dispatch_status).to eq("pending")
        end
      end

      context "in status of 'stopped'," do
        before do
          @vim_broker_worker.update(:status => 'stopped')
        end

        it "should not be dispatched" do
          JobProxyDispatcher.dispatch
          @job.reload
          expect(@job.state).to eq("waiting_to_start")
          expect(@job.dispatch_status).to eq("pending")
        end
      end

      context "in status of 'killed'," do
        before do
          @vim_broker_worker.update(:status => 'killed')
        end

        it "should not be dispatched" do
          JobProxyDispatcher.dispatch
          @job.reload
          expect(@job.state).to eq("waiting_to_start")
          expect(@job.dispatch_status).to eq("pending")
        end
      end

      context "in status of 'started'," do
        before do
          @vim_broker_worker.update(:status => 'started')
          JobProxyDispatcher.dispatch
          @job.reload
        end

        it "should get dispatched" do
          expect(@job.state).to eq("waiting_to_start")
          expect(@job.dispatch_status).to eq("active")
        end

        context "when signaled with 'start'" do
          before do
            q = MiqQueue.last
            q.delivered(*q.deliver)
            @job.reload
          end

          it "should go to state of 'wait_for_policy'" do
            expect(@job.state).to eq('wait_for_policy')
            expect(MiqQueue.where(:class_name => "MiqAeEngine", :method_name => "deliver").count).to eq(1)
          end

          it "should call callback when message is delivered" do
            allow(@job).to receive(:signal).and_return(true)
            vm_scan = double("VmScan")
            allow(VmScan).to receive(:find).and_return(vm_scan)
            expect(vm_scan).to receive(:check_policy_complete).with(@server.my_zone, "ok", any_args)
            q = MiqQueue.where(:class_name => "MiqAeEngine", :method_name => "deliver").first
            q.delivered(*q.deliver)
          end
        end
      end
    end

    context "#start_user_event_message" do
      it "without send" do
        expect(@vm.ext_management_system).to receive(:vm_log_user_event)
        @job.start_user_event_message(@vm)
      end

      it "with send = true" do
        expect(@vm.ext_management_system).to receive(:vm_log_user_event)
        @job.start_user_event_message(@vm, true)
      end

      it "with send = false" do
        expect(@vm.ext_management_system).not_to receive(:vm_log_user_event)
        @job.start_user_event_message(@vm, false)
      end
    end

    context "#end_user_event_message" do
      it "without send" do
        expect(@vm.ext_management_system).to receive(:vm_log_user_event)
        @job.end_user_event_message(@vm)
      end

      it "with send = true" do
        expect(@vm.ext_management_system).to receive(:vm_log_user_event)
        @job.end_user_event_message(@vm, true)
      end

      it "with send = false" do
        expect(@vm.ext_management_system).not_to receive(:vm_log_user_event)
        @job.end_user_event_message(@vm, false)
      end

      it "should not send the end message twice" do
        expect(@vm.ext_management_system).to receive(:vm_log_user_event).once
        @job.end_user_event_message(@vm)
        @job.end_user_event_message(@vm)
      end
    end

    context "#create_scan_args" do
      it "should have no vmScanProfiles by default" do
        args = @job.create_scan_args(@vm)
        expect(args["vmScanProfiles"]).to eq []
      end

      it "should have vmScanProfiles from scan_profiles option" do
        profiles = [{:name => 'default'}]
        @job.options[:scan_profiles] = profiles
        args = @job.create_scan_args(@vm)
        expect(args["vmScanProfiles"]).to eq profiles
      end
    end

    context "#call_check_policy" do
      it "should raise vm_scan_start for Vm" do
        expect(MiqAeEvent).to receive(:raise_evm_event).with(
          "vm_scan_start",
          an_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm),
          an_instance_of(Hash),
          an_instance_of(Hash)
        )
        @job.call_check_policy
      end

      it "should raise vm_scan_start for template" do
        template = FactoryBot.create(
          :template_vmware,
          :name                  => "test_vm",
          :location              => "abc/abc.vmx",
          :raw_power_state       => 'poweredOn',
          :host                  => @host,
          :ext_management_system => @ems,
          :miq_group             => @user.current_group,
          :evm_owner             => @user,
          :storage               => @storage
        )

        Job.destroy_all # clear the first job from before section
        template.scan
        job_item = MiqQueue.find_by(:class_name => "MiqAeEngine", :method_name => "deliver")
        job_item.delivered(*job_item.deliver)

        job = Job.first

        expect(MiqAeEvent).to receive(:raise_evm_event).with(
          "vm_scan_start",
          an_instance_of(ManageIQ::Providers::Vmware::InfraManager::Template),
          an_instance_of(Hash),
          an_instance_of(Hash)
        )
        job.call_check_policy
      end
    end

    describe "#call_snapshot_create" do
      context "for providers other than OpenStack and Microsoft" do
        before { @job.miq_server_id = @server.id }

        it "does not call #create_snapshot but sends signal :snapshot_complete" do
          expect(@job).to receive(:signal).with(:snapshot_complete)
          expect(@job).not_to receive(:create_snapshot)
          @job.call_snapshot_create
        end

        context "if snapshot for scan required" do
          before do
            allow(@vm).to receive(:require_snapshot_for_scan?).and_return(true)
            allow(MiqServer).to receive(:use_broker_for_embedded_proxy?).and_return(true)
          end

          it "sends signal :broker_unavailable and :snapshot_complete if there is no MiqVimBrokerWorker available" do
            allow(MiqVimBrokerWorker).to receive(:available?).and_return(false)
            expect(@job).to receive(:signal).with(:broker_unavailable)
            expect(@job).not_to receive(:signal).with(:snapshot_complete)
            @job.call_snapshot_create
          end

          it "logs user event and sends signal :snapshot_complete" do
            allow(MiqVimBrokerWorker).to receive(:available?).and_return(true)
            expect(@job).not_to receive(:signal).with(:broker_unavailable)
            expect(@job).to receive(:signal).with(:snapshot_complete)
            expect(@job).to receive(:log_user_event)
            @job.call_snapshot_create
          end
        end

        context "if snapshot for scan not requiered" do
          it "logs user events: Initializing and sends signal :snapshot_complete" do
            allow(@vm).to receive(:require_snapshot_for_scan?).and_return(false)
            event_message = "EVM SmartState Analysis Initiated for VM [#{@vm.name}]"
            expect(@job).to receive(:signal).with(:snapshot_complete)
            expect(@job).to receive(:log_user_event).with(event_message, any_args)
            @job.call_snapshot_create
          end
        end
      end
    end

    describe "#wait_for_vim_broker" do
      it "waits 60 seconds inside loop and send signal :start_snapshot if MiqVimBrokerWorker is available" do
        allow(@job).to receive(:loop).and_yield
        expect(@job).to receive(:sleep).with(60)
        expect(@job).to receive(:signal).with(:start_snapshot)
        @job.wait_for_vim_broker
      end
    end

    describe "#call_scan" do
      before do
        @job.miq_server_id = @server.id
        allow(VmOrTemplate).to receive(:find).with(@vm.id).and_return(@vm)
        allow(MiqServer).to receive(:find).with(@server.id).and_return(@server)
      end

      it "calls #scan_metadata on target VM and as result " do
        expect(@vm).to receive(:scan_metadata)
        @job.call_scan
      end

      it "triggers adding MiqServer#scan_metada to MiqQueue" do
        @job.call_scan
        queue_item = MiqQueue.where(:class_name => "MiqServer", :queue_name => "smartproxy").first
        expect(@server.id).to eq queue_item.instance_id
        expect(queue_item.args[0].vm_guid).to eq @vm.guid
      end

      it "updates job message" do
        allow(@vm).to receive(:scan_metadata)
        @job.call_scan
        expect(@job.message).to eq "Scanning for metadata from VM"
      end

      it "sends signal :abort if there is any error" do
        allow(@vm).to receive(:scan_metadata).and_raise("Any Error")
        expect(@job).to receive(:signal).with(:abort, any_args)
        @job.call_scan
      end
    end

    describe "#call_synchronize" do
      before do
        @job.miq_server_id = @server.id
        allow(VmOrTemplate).to receive(:find).with(@vm.id).and_return(@vm)
        allow(MiqServer).to receive(:find).with(@server.id).and_return(@server)
      end

      it "calls VmOrTemlate#synch_metadata with correct parameters" do
        expect(@vm).to receive(:sync_metadata).with(any_args, "taskid" => @job.jobid, "host" => @server)
        @job.call_synchronize
      end

      it "sends signal :abort if there is any error" do
        allow(@vm).to receive(:sync_metadata).and_raise("Any Error")
        expect(@job).to receive(:signal).with(:abort, any_args)
        @job.call_synchronize
      end

      it "does not updates job status" do
        expect(@job).to receive(:set_status).with("Synchronizing metadata from VM")
        @job.call_synchronize
      end

      it "executes Job#dispatch_finish" do
        expect(@job).to receive(:dispatch_finish)
        @job.call_synchronize
      end
    end

    describe "#call_snapshot_delete" do
      let(:snapshot_description) { "Snapshot description" }
      before do
        allow(VmOrTemplate).to receive(:find).with(@vm.id).and_return(@vm)
        @job.update(:state => 'snapshot_delete')
        @job.context[:snapshot_mor] = snapshot_description
        # always sent 'snapshot_complete'
        expect(@job).to receive(:signal).with(:snapshot_complete)
      end

      it "does not call 'delete_snapshot' if there is no provider this VM belongs to" do
        allow(@vm).to receive(:ext_management_system).and_return(false)
        expect(@job).not_to receive(:delete_snapshot)
        @job.call_snapshot_delete
        expect(@job.message).to eq "No Providers available to delete snapshot, skipping"
      end

      it "calls 'delete_snapshot'" do
        allow(@vm).to receive(:ext_management_system).and_return(true)
        expect(@job).to receive(:delete_snapshot)
        @job.call_snapshot_delete
        expect(@job.message).to eq "Snapshot deleted: reference: [#{snapshot_description}]"
      end
    end
  end

  context "A single VM Scan Job on Openstack provider" do
    let(:vm) do
      vm = double("ManageIQ::Providers::Openstack::CloudManager::Vm")
      allow(vm).to receive(:kind_of?).with(ManageIQ::Providers::Openstack::CloudManager::Vm).and_return(true)
      allow(vm).to receive(:kind_of?).with(ManageIQ::Providers::Microsoft::InfraManager::Vm).and_return(false)
      vm
    end
    let(:job) { VmScan.new(:context => {}, :options => {}) }

    describe "#call_snapshot_create" do
      it "executes VmScan#create_snapshot and send signal :snapshot_complete" do
        allow(VmOrTemplate).to receive(:find).and_return(vm)
        expect(job).to receive(:create_snapshot).and_return(true)
        expect(job).to receive(:signal).with(:snapshot_complete)
        job.call_snapshot_create
      end
    end
  end

  context "A single VM Scan Job on Microsoft provider" do
    let(:vm) do
      vm = double("ManageIQ::Providers::Microsoft::InfraManager::Vm")
      allow(vm).to receive(:kind_of?).with(ManageIQ::Providers::Openstack::CloudManager::Vm).and_return(false)
      allow(vm).to receive(:kind_of?).with(ManageIQ::Providers::Microsoft::InfraManager::Vm).and_return(true)
      vm
    end
    let(:job) { VmScan.new(:context => {}, :options => {}) }

    describe "#call_snapshot_create" do
      it "executes VmScan#create_snapshot and send signal :snapshot_complete" do
        allow(VmOrTemplate).to receive(:find).and_return(vm)
        expect(job).to receive(:create_snapshot).and_return(true)
        expect(job).to receive(:signal).with(:snapshot_complete)
        job.call_snapshot_create
      end
    end
  end

  # test cases for BZ #1454936
  context "A VM Scan job in multiple zones" do
    before do
      # local zone
      @server1 = EvmSpecHelper.local_miq_server(:capabilities => {:vixDisk => true})
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
      @server2 = EvmSpecHelper.remote_miq_server(:capabilities => {:vixDisk => true})
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

        it "sends signal :start_snapshot if status is 'ok' to local zone" do
          expect(MiqQueue).to receive(:put).with(
            :class_name  => @job.class.to_s,
            :instance_id => @job.id,
            :method_name => "signal",
            :args        => [:start_snapshot],
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

        it "signals :start_snapshot if status is 'ok' to remote zone" do
          expect(MiqQueue).to receive(:put).with(
            :class_name  => @job.class.to_s,
            :instance_id => @job.id,
            :method_name => "signal",
            :args        => [:start_snapshot],
            :zone        => @server2.my_zone,
            :role        => "smartstate"
          )
          @job.check_policy_complete(@server2.my_zone, 'ok', nil, nil)
        end
      end
    end
  end

  private

  def assign_smartproxy_role_to_server(server)
    server_role = FactoryBot.create(
      :server_role,
      :name              => "smartproxy",
      :description       => "SmartProxy",
      :max_concurrent    => 1,
      :external_failover => false,
      :role_scope        => "zone"
    )
    FactoryBot.create(
      :assigned_server_role,
      :miq_server_id  => server.id,
      :server_role_id => server_role.id,
      :active         => true,
      :priority       => AssignedServerRole::DEFAULT_PRIORITY
    )
  end
end
