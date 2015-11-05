require "spec_helper"

describe VmScan do
  context "A single VM Scan Job," do
    before(:each) do
      @server = EvmSpecHelper.local_miq_server

      # TODO: We should be able to set values so we don't need to stub behavior
      MiqServer.any_instance.stub(:is_a_proxy? => true, :has_active_role? => true, :is_vix_disk? => true)
      ManageIQ::Providers::Vmware::InfraManager.any_instance.stub(:authentication_status_ok? => true)
      Vm.stub(:scan_via_ems? => true)

      @user      = FactoryGirl.create(:user_with_group, :userid => "tester")
      @ems       = FactoryGirl.create(:ems_vmware,       :name => "Test EMS", :zone => @server.zone, :tenant => FactoryGirl.create(:tenant))
      @storage   = FactoryGirl.create(:storage,          :name => "test_storage", :store_type => "VMFS")
      @host      = FactoryGirl.create(:host,             :name => "test_host", :hostname => "test_host", :state => 'on', :ext_management_system => @ems)
      @vm        = FactoryGirl.create(:vm_vmware,        :name => "test_vm", :location => "abc/abc.vmx",
                                      :raw_power_state       => 'poweredOn',
                                      :host                  => @host,
                                      :ext_management_system => @ems,
                                      :miq_group             => @user.current_group,
                                      :evm_owner             => @user,
                                      :storage               => @storage
                                     )
      @ems_auth  = FactoryGirl.create(:authentication, :resource => @ems)

      MiqEventDefinition.stub(:find_by_name => true)
      @job = @vm.scan
      MiqQueue.delete_all # clear the queue items that are not related to Vm scan testing
    end

    it "should start in a state of waiting_to_start" do
      @job.state.should == "waiting_to_start"
    end

    it "should start in a dispatch_status of pending" do
      @job.dispatch_status.should == "pending"
    end

    it "should respond properly to proxies4job" do
      @vm.proxies4job[:message].should == "Perform SmartState Analysis on this VM"
    end

    it "should respond properly to storage2hosts" do
      @vm.storage2hosts.should == [@host]
    end

    context "without MiqVimBrokerWorker record," do
      it "should not be dispatched" do
        JobProxyDispatcher.dispatch
        @job.reload
        @job.state.should == "waiting_to_start"
        @job.dispatch_status.should == "pending"
      end
    end

    context "without Broker Running and with valid MiqVimBrokerWorker record," do
      before(:each) do
        @vim_broker_worker = FactoryGirl.create(:miq_vim_broker_worker, :miq_server_id => @server.id)
      end

      context "in status of 'starting'," do
        before(:each) do
          @vim_broker_worker.update_attributes(:status => 'starting')
        end

        it "should not be dispatched" do
          JobProxyDispatcher.dispatch
          @job.reload
          @job.state.should == "waiting_to_start"
          @job.dispatch_status.should == "pending"
        end
      end

      context "in status of 'stopped'," do
        before(:each) do
          @vim_broker_worker.update_attributes(:status => 'stopped')
        end

        it "should not be dispatched" do
          JobProxyDispatcher.dispatch
          @job.reload
          @job.state.should == "waiting_to_start"
          @job.dispatch_status.should == "pending"
        end
      end

      context "in status of 'killed'," do
        before(:each) do
          @vim_broker_worker.update_attributes(:status => 'killed')
        end

        it "should not be dispatched" do
          JobProxyDispatcher.dispatch
          @job.reload
          @job.state.should == "waiting_to_start"
          @job.dispatch_status.should == "pending"
        end
      end

      context "in status of 'started'," do
        before(:each) do
          @vim_broker_worker.update_attributes(:status => 'started')
          JobProxyDispatcher.dispatch
          @job.reload
        end

        it "should get dispatched" do
          @job.state.should == "waiting_to_start"
          @job.dispatch_status.should == "active"
        end

        context "when signaled with 'start'" do
          before(:each) do
            q = MiqQueue.last
            q.delivered(*q.deliver)
            @job.reload
          end

          it "should go to state of 'wait_for_policy'" do
            @job.state.should == 'wait_for_policy'
            MiqQueue.where(:class_name => "MiqAeEngine", :method_name => "deliver").count.should eq(1)
          end

          it "should call callback when message is delivered" do
            VmScan.any_instance.stub(:signal => true)
            VmScan.any_instance.should_receive(:check_policy_complete)
            q = MiqQueue.where(:class_name => "MiqAeEngine", :method_name => "deliver").first
            q.delivered(*q.deliver)
          end
        end
      end
    end

    context "#start_user_event_message" do
      it "without send" do
        @vm.ext_management_system.should_receive(:vm_log_user_event)
        @job.start_user_event_message(@vm)
      end

      it "with send = true" do
        @vm.ext_management_system.should_receive(:vm_log_user_event)
        @job.start_user_event_message(@vm, true)
      end

      it "with send = false" do
        @vm.ext_management_system.should_not_receive(:vm_log_user_event)
        @job.start_user_event_message(@vm, false)
      end
    end

    context "#end_user_event_message" do
      it "without send" do
        @vm.ext_management_system.should_receive(:vm_log_user_event)
        @job.end_user_event_message(@vm)
      end

      it "with send = true" do
        @vm.ext_management_system.should_receive(:vm_log_user_event)
        @job.end_user_event_message(@vm, true)
      end

      it "with send = false" do
        @vm.ext_management_system.should_not_receive(:vm_log_user_event)
        @job.end_user_event_message(@vm, false)
      end

      it "should not send the end message twice" do
        @vm.ext_management_system.should_receive(:vm_log_user_event).once
        @job.end_user_event_message(@vm)
        @job.end_user_event_message(@vm)
      end
    end

    context "#create_scan_args" do
      it "should have no vmScanProfiles by default" do
        args = @job.create_scan_args(@vm)
        args["vmScanProfiles"].should eq []
      end

      it "should have vmScanProfiles from scan_profiles option" do
        profiles = [ScanItemSet.any_instance.stub(:name => 'default')]
        @job.options[:scan_profiles] = profiles
        args = @job.create_scan_args(@vm)
        args["vmScanProfiles"].should eq profiles
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
        template = FactoryGirl.create(
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
        job = template.scan

        expect(MiqAeEvent).to receive(:raise_evm_event).with(
          "vm_scan_start",
          an_instance_of(ManageIQ::Providers::Vmware::InfraManager::Template),
          an_instance_of(Hash),
          an_instance_of(Hash)
        )
        job.call_check_policy
      end
    end
  end
end
