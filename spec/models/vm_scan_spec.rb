describe VmScan do
  context "A single VM Scan Job," do
    before(:each) do
      @server = EvmSpecHelper.local_miq_server

      # TODO: We should be able to set values so we don't need to stub behavior
      allow_any_instance_of(MiqServer).to receive_messages(:is_a_proxy? => true, :has_active_role? => true, :is_vix_disk? => true)
      allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:authentication_status_ok? => true)
      allow(Vm).to receive_messages(:scan_via_ems? => true)

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

      allow(MiqEventDefinition).to receive_messages(:find_by_name => true)
      allow(MiqAeEngine).to receive_messages(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])

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
          expect(@job.state).to eq("waiting_to_start")
          expect(@job.dispatch_status).to eq("pending")
        end
      end

      context "in status of 'stopped'," do
        before(:each) do
          @vim_broker_worker.update_attributes(:status => 'stopped')
        end

        it "should not be dispatched" do
          JobProxyDispatcher.dispatch
          @job.reload
          expect(@job.state).to eq("waiting_to_start")
          expect(@job.dispatch_status).to eq("pending")
        end
      end

      context "in status of 'killed'," do
        before(:each) do
          @vim_broker_worker.update_attributes(:status => 'killed')
        end

        it "should not be dispatched" do
          JobProxyDispatcher.dispatch
          @job.reload
          expect(@job.state).to eq("waiting_to_start")
          expect(@job.dispatch_status).to eq("pending")
        end
      end

      context "in status of 'started'," do
        before(:each) do
          @vim_broker_worker.update_attributes(:status => 'started')
          JobProxyDispatcher.dispatch
          @job.reload
        end

        it "should get dispatched" do
          expect(@job.state).to eq("waiting_to_start")
          expect(@job.dispatch_status).to eq("active")
        end

        context "when signaled with 'start'" do
          before(:each) do
            q = MiqQueue.last
            q.delivered(*q.deliver)
            @job.reload
          end

          it "should go to state of 'wait_for_policy'" do
            expect(@job.state).to eq('wait_for_policy')
            expect(MiqQueue.where(:class_name => "MiqAeEngine", :method_name => "deliver").count).to eq(1)
          end

          it "should call callback when message is delivered" do
            allow_any_instance_of(VmScan).to receive_messages(:signal => true)
            expect_any_instance_of(VmScan).to receive(:check_policy_complete)
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
  end
end
