RSpec.describe ServiceReconfigureTask do
  let(:user)     { FactoryBot.create(:user_with_group) }
  let(:template) { FactoryBot.create(:service_template, :name => 'Test Template') }
  let(:service)  { FactoryBot.create(:service, :name => 'Test Service', :service_template => template) }

  let(:request) do
    ServiceReconfigureRequest.create(:requester    => user,
                                     :options      => {:src_id => service.id},
                                     :request_type => 'service_reconfigure')
  end

  let(:task) do
    ServiceReconfigureTask.create(:userid       => user.userid,
                                  :miq_request  => request,
                                  :source       => service,
                                  :request_type => 'service_reconfigure')
  end

  describe "#self.base_model" do
    it "should return ServiceReconfigureTask" do
      expect(ServiceReconfigureTask.base_model).to eq(ServiceReconfigureTask)
    end
  end

  describe "#self.get_description" do
    it "returns a description based upon the source service name" do
      expect(ServiceReconfigureTask.get_description(request)).to eq("Service Reconfigure for: Test Service")
    end
  end

  describe "#after_ae_delivery" do
    it "updates the task status to Ok if automation run successfully" do
      expect(task).to receive(:update_and_notify_parent).with(
        :state   => 'finished',
        :status  => 'Ok',
        :message => 'Service Reconfigure completed'
      )
      task.after_ae_delivery('ok')
    end

    it "updates the task status to Error if automation encountered an error" do
      expect(task).to receive(:update_and_notify_parent).with(
        :state   => 'finished',
        :status  => 'Error',
        :message => 'Service Reconfigure failed'
      )
      task.after_ae_delivery('error')
    end

    it "updates service's dialog options if reconfigure passes" do
      service.update(:options => {:dialog => {:var1 => "value"}})
      task.options[:dialog] = {:var1 => "new_value"}
      task.after_ae_delivery('ok')
      expect(service.options[:dialog]).to include(:var1 => "new_value")
    end

    it "does not update service's dialog options if reconfigure fails" do
      service.update(:options => {:dialog => {:var1 => "value"}})
      task.options[:dialog] = {:var1 => "new_value"}
      task.after_ae_delivery('error')
      expect(service.options[:dialog]).to include(:var1 => "value")
    end
  end

  describe "#after_request_task_create" do
    it "should set the task description" do
      task.after_request_task_create
      expect(task.description).to eq("Service Reconfigure for: Test Service")
    end
  end

  describe "#deliver_to_automate" do
    before do
      allow(request).to receive(:approved?).and_return(true)
    end

    context "automation entry point available" do
      before do
        FactoryBot.create(:resource_action, :action       => 'Reconfigure',
                                            :resource     => template,
                                            :ae_namespace => 'namespace',
                                            :ae_class     => 'class',
                                            :ae_instance  => 'instance')
      end

      it "queues the reconfigure automate entry point" do
        task.options[:dialog] = {'dialog_key' => 'value'}
        automate_args = {
          :object_type      => 'ServiceReconfigureTask',
          :object_id        => task.id,
          :namespace        => 'namespace',
          :class_name       => 'class',
          :instance_name    => 'instance',
          :automate_message => 'create',
          :attrs            => task.options[:dialog].merge("request" => task.request_type, "Service::service" => service.id),
          :user_id          => user.id,
          :miq_group_id     => user.current_group_id,
          :tenant_id        => user.current_tenant.id,
        }
        expect(user.current_tenant).to be_truthy
        expect(MiqQueue).to receive(:put).with(
          :class_name     => 'MiqAeEngine',
          :method_name    => 'deliver',
          :args           => [automate_args],
          :role           => 'automate',
          :zone           => nil,
          :tracking_label => "r#{request.id}_service_reconfigure_task_#{task.id}"
        )
        task.deliver_to_automate
      end

      it "updates the task state to pending" do
        allow(MiqQueue).to receive(:put)
        expect(task).to receive(:update_and_notify_parent).with(
          :state   => 'pending',
          :status  => 'Ok',
          :message => 'Automation Starting'
        )
        task.deliver_to_automate
      end
    end

    context "automation entry point missing" do
      it "updates the task state to finished" do
        expect(task).to receive(:update_and_notify_parent).with(
          :state   => 'finished',
          :status  => 'Ok',
          :message => 'Service Reconfigure completed'
        )
        task.deliver_to_automate
      end
    end
  end

  describe "#update_and_notify_parent lifecycle state" do
    before { task } # ensure task is persisted

    context "when state transitions to 'pending'" do
      it "sets the service lifecycle_state to 'provisioning'" do
        task.update_and_notify_parent(:state => "pending", :status => "Ok", :message => "Automation Starting")
        expect(service.reload.lifecycle_state).to eq("provisioning")
      end
    end

    context "when state transitions to 'active'" do
      before { task.update!(:state => "pending") }

      it "sets the service lifecycle_state to 'provisioning'" do
        task.update_and_notify_parent(:state => "active", :status => "Ok", :message => "In Process")
        expect(service.reload.lifecycle_state).to eq("provisioning")
      end
    end

    context "workflow path via before_ae_starts" do
      it "transitions task to active and sets service lifecycle_state to 'provisioning'" do
        task.before_ae_starts({})
        expect(task.reload.state).to eq("active")
        expect(service.reload.lifecycle_state).to eq("provisioning")
      end

      it "is a no-op when task is already active" do
        task.update!(:state => "active")
        expect(task).not_to receive(:update_and_notify_parent)
        task.before_ae_starts({})
      end
    end

    context "when state transitions to 'finished' with status 'Ok'" do
      before { task.update!(:state => "active") }

      it "sets the service lifecycle_state to 'provisioned'" do
        task.update_and_notify_parent(:state => "finished", :status => "Ok", :message => "Service Reconfigure completed")
        expect(service.reload.lifecycle_state).to eq("provisioned")
      end
    end

    context "when state transitions to 'finished' with status 'Error'" do
      before { task.update!(:state => "active") }

      it "sets the service lifecycle_state to 'error_in_provisioning'" do
        task.update_and_notify_parent(:state => "finished", :status => "Error", :message => "Service Reconfigure failed")
        expect(service.reload.lifecycle_state).to eq("error_in_provisioning")
      end
    end

    context "when state does not change" do
      before { task.update!(:state => "active", :status => "Ok") }

      it "does not update service lifecycle_state" do
        expect(service).not_to receive(:start_reconfiguration)
        expect(service).not_to receive(:finish_reconfiguration)
        expect(service).not_to receive(:reconfiguration_error)
        task.update_and_notify_parent(:message => "still active")
      end
    end
  end
end
