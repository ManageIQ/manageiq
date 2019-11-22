describe VmScan do
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
end
