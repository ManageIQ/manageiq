require "spec_helper"

describe VmScan do
  context "A single VM Scan Job," do
    before(:each) do
      @guid = MiqUUID.new_guid
      @zone   = FactoryGirl.create(:zone)
      @server = FactoryGirl.create(:miq_server, :zone => @zone, :guid => @guid)
      MiqServer.stub(:my_guid => @guid)
      MiqServer.my_server(true)

      #TODO: We should be able to set values so we don't need to stub behavior
      MiqServer.any_instance.stub(:is_vix_disk? => true)
      MiqServer.any_instance.stub(:is_a_proxy? => true)
      MiqServer.any_instance.stub(:has_active_role? => true)

      @ems       = FactoryGirl.create(:ems_vmware,           :name => "Test EMS", :zone => @zone)
      @proxy     = FactoryGirl.create(:active_cos_proxy, :name => "test_cos_proxy")
      @storage   = FactoryGirl.create(:storage,          :name => "test_storage", :store_type => "VMFS")
      @host      = FactoryGirl.create(:host,             :name => "test_host", :hostname => "test_host", :state => 'on', :ext_management_system => @ems, :miq_proxy => @proxy)
      @vm        = FactoryGirl.create(:vm_vmware,               :name => "test_vm", :location => "abc/abc.vmx", :state => 'on', :host => @host, :ext_management_system => @ems, :storage => @storage)
      @ems_auth  = FactoryGirl.create(:authentication, :resource => @ems)

      @job = @vm.scan
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
          @job.state.should           == "waiting_to_start"
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
          @job.state.should           == "waiting_to_start"
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
          @job.state.should           == "waiting_to_start"
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
          @job.state.should           == "waiting_to_start"
          @job.dispatch_status.should == "active"
        end

        # context "when signaled to start" do
        #   before(:each) do
        #     @job.signal(:start)
        #   end
        #
        #   it "should go to state of 'wait_for_broker'" do
        #     p @job
        #     @job.state.should == "wait_for_broker"
        #   end
        # end

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

  end

end
