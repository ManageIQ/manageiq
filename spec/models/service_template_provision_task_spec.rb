describe ServiceTemplateProvisionTask do
  context "with multiple tasks" do
    before(:each) do
      @admin = FactoryGirl.create(:user_with_group)

      @request = FactoryGirl.create(:service_template_provision_request,
                                    :description => 'Service Request',
                                    :requester   => @admin)
      @task_0 = create_stp('Task 0 (Top)')
      @task_1 = create_stp('Task 1', 'pending', 7, 1)
      @task_1_1 = create_stp('Task 1 - 1', 'pending', 1, 3)
      @task_1_2 = create_stp('Task 1 - 2', 'pending', 5, 1)
      @task_2 = create_stp('Task 2', 'pending', 9, 1)
      @task_2_1 = create_stp('Task 2 - 1', 'pending', 2, 1)
      @task_3 = create_stp('Task 3', 'finished', 3, 5)

      @request.miq_request_tasks = [@task_0, @task_1, @task_1_1, @task_1_2, @task_2, @task_2_1, @task_3]
      @task_0.miq_request_tasks  = [@task_1, @task_2, @task_3]
      @task_1.miq_request_task   =  @task_0
      @task_1.miq_request_tasks  = [@task_1_1, @task_1_2]
      @task_1_1.miq_request_task =  @task_1
      @task_1_2.miq_request_task =  @task_1
      @task_2.miq_request_task   =  @task_0
      @task_2.miq_request_tasks  = [@task_2_1]
      @task_3.miq_request_task   =  @task_0
    end

    def create_stp(description, state = 'pending', prov_index = nil, scaling_max = nil)
      if prov_index && scaling_max
        options = {:service_resource_id => service_resource_id(prov_index, scaling_max)}
      else
        options = {}
      end
      FactoryGirl.create(:service_template_provision_task,
                         :description    => description,
                         :userid         => @admin.userid,
                         :state          => state,
                         :miq_request_id => @request.id,
                         :options        => options)
    end

    def service_resource_id(index, scaling_max)
      FactoryGirl.create(:service_resource,
                         :provision_index => index,
                         :scaling_min     => 1,
                         :scaling_max     => scaling_max,
                         :resource_type   => 'ServiceTemplate').id
    end

    describe "#before_ae_starts" do
      context 'task is pending' do
        it "updates the task state to active" do
          @task_0.update_attribute(:state, 'pending')
          @task_0.before_ae_starts({})
          expect(@task_0).to have_attributes(:state => 'active', :status => 'Ok', :message => 'In Process')
        end
      end

      context 'task is queued' do
        it "updates the task state to active" do
          @task_0.update_attribute(:state, 'queued')
          @task_0.before_ae_starts({})
          expect(@task_0).to have_attributes(:state => 'active', :status => 'Ok', :message => 'In Process')
        end
      end

      context 'task is provisioned' do
        it "does not update task state" do
          @task_0.update_attribute(:state, 'provisioned')
          @task_0.before_ae_starts({})
          expect(@task_0).to have_attributes(:state => 'provisioned', :status => 'Ok')
        end
      end
    end

    describe "#deliver_to_automate" do
      it "delivers to the queue when the state is not active" do
        @task_0.state         = 'pending'
        zone                  = FactoryGirl.create(:zone, :name => "special")
        orchestration_manager = FactoryGirl.create(:ext_management_system, :zone => zone)
        @task_0.source        = FactoryGirl.create(:service_template_orchestration, :orchestration_manager => orchestration_manager)
        automate_args         = {
          :object_type      => 'ServiceTemplateProvisionTask',
          :object_id        => @task_0.id,
          :namespace        => 'Service/Provisioning/StateMachines',
          :class_name       => 'ServiceProvision_Template',
          :instance_name    => 'clone_to_service',
          :automate_message => 'create',
          :attrs            => {'request' => 'clone_to_service'},
          :user_id          => @admin.id,
          :miq_group_id     => @admin.current_group_id,
          :tenant_id        => @admin.current_tenant.id,
        }
        allow(@request).to receive(:approved?).and_return(true)
        expect(MiqQueue).to receive(:put).with(
          :class_name  => 'MiqAeEngine',
          :method_name => 'deliver',
          :args        => [automate_args],
          :role        => 'automate',
          :zone        => 'special',
          :task_id     => "service_template_provision_task_#{@task_0.id}")
        @task_0.deliver_to_automate
      end

      it "raises an error when the state is already active" do
        @task_0.state = 'active'
        expect { @task_0.deliver_to_automate }.to raise_error('Service_Template_Provisioning request is already being processed')
      end
    end

    describe "#execute_queue" do
      it 'delivers to the queue when the state is active' do
        @task_0.state = 'active'
        miq_callback = {
          :class_name  => 'ServiceTemplateProvisionTask',
          :instance_id => @task_0.id,
          :method_name => :execute_callback
        }
        allow(@request).to receive(:approved?).and_return(true)
        allow(MiqServer).to receive(:my_zone).and_return('a_zone')
        expect(MiqQueue).to receive(:put).with(
          :class_name   => 'ServiceTemplateProvisionTask',
          :instance_id  => @task_0.id,
          :method_name  => 'execute',
          :role         => 'ems_operations',
          :zone         => 'a_zone',
          :task_id      => "service_template_provision_task_#{@task_0.id}",
          :deliver_on   => nil,
          :miq_callback => miq_callback)
        @task_0.execute_queue
      end

      it 'raises an error when the state is already finished' do
        @task_0.state = 'finished'
        expect { @task_0.execute_queue }.to raise_error('Service_Template_Provisioning request has already been processed')
      end
    end

    it "service 1 child provision priority" do
      expect(@task_1_1.provision_priority).to eq(1)
    end

    it "service 2 child provision priority" do
      expect(@task_2_1.provision_priority).to eq(2)
    end

    it "service 1 can run now" do
      expect(@task_1.group_sequence_run_now?).to eq(true)
    end

    it "service 1 child 1 can run now" do
      expect(@task_1_1.group_sequence_run_now?).to eq(true)
    end

    it "service 1 child 2 cannot run yet" do
      expect(@task_1_2.group_sequence_run_now?).to eq(false)
    end

    it "service 2 cannot run yet" do
      expect(@task_2.group_sequence_run_now?).to eq(false)
    end

    it "service 2 child 1 cannot run yet" do
      expect(@task_2_1.group_sequence_run_now?).to eq(false)
    end

    it "service 3 can run now" do
      expect(@task_3.group_sequence_run_now?).to eq(true)
    end

    it "call task_finished" do
      expect(@task_1_2).to receive(:task_finished).once
      @task_1_2.update_and_notify_parent(:state => "finished", :status => "Ok", :message => "Test Message")
    end

    it "update_request_status - no message" do
      expect(@task_1_2.message).to be_nil
      @task_1_2.update_request_status
      expect(@task_1_2.message).to be_blank
    end

    it "update_request_status with message override" do
      expect(@task_1_2.message).to be_nil
      @task_1_2.update_attribute(:options, :user_message => "New test message")
      @task_1_2.update_request_status
      expect(@task_1_2.message).to eq("New test message")
    end

    it "update_and_notify_parent all tasks finished sets bundle task finished" do
      @request.miq_request_tasks.each { |t| t.update_attributes(:state => "finished") }
      expect(@task_0.state).to eq("finished")
    end

    it "update_and_notify_parent all service children and parents finished sets bundle task provisioned" do
      @request.miq_request_tasks.each { |t| t.update_attributes(:state => "finished") }
      @task_0.update_attributes(:state => "active")
      @task_1.update_and_notify_parent(:state => "finished", :status => "Ok", :message => "Test Message")
      @task_0.reload
      expect(@task_0.state).to eq("provisioned")
    end

    it "update_and_notify_parent one service children finished, parent not finished sets parent task provisioned" do
      @task_1_1.update_attributes(:state => "finished")
      @task_1_2.update_attributes(:state => "finished")
      @task_1_2.update_and_notify_parent(:state => "finished", :status => "Ok", :message => "Test Message")
      @task_1.reload
      expect(@task_1.state).to eq("provisioned")
      expect(@task_0.state).not_to eq("finished")
    end

    it "update_and_notify_parent one service children and parent finished, sets parent task finished" do
      @task_2_1.update_attributes(:state => "finished")
      @task_2.update_attributes(:state => "finished")
      @task_2_1.update_and_notify_parent(:state => "finished", :status => "Ok", :message => "Test Message")
      expect(@task_2.state).to eq("finished")
      expect(@task_0.state).not_to eq("finished")
    end

    context "with a service" do
      before(:each) do
        @service = FactoryGirl.create(:service, :name => 'Test Service')
      end

      it "raise provisioned event" do
        expect(MiqEvent).to receive(:raise_evm_event).with(@service, :service_provisioned)

        @task_1_2.destination = @service
        @task_1_2.update_and_notify_parent(:state => "finished", :status => "Ok", :message => "Test Message")
      end
    end
  end
end
