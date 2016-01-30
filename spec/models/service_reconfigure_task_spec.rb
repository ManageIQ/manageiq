describe ServiceReconfigureTask do
  let(:user)     { FactoryGirl.create(:user_with_group) }
  let(:template) { FactoryGirl.create(:service_template, :name => 'Test Template') }
  let(:service)  { FactoryGirl.create(:service, :name => 'Test Service', :service_template => template) }

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
        :message => 'Service Reconfigure completed')
      task.after_ae_delivery('ok')
    end

    it "updates the task status to Error if automation encountered an error" do
      expect(task).to receive(:update_and_notify_parent).with(
        :state   => 'finished',
        :status  => 'Error',
        :message => 'Service Reconfigure failed')
      task.after_ae_delivery('error')
    end
  end

  describe "#after_request_task_create" do
    it "should set the task description" do
      task.after_request_task_create
      expect(task.description).to eq("Service Reconfigure for: Test Service")
    end
  end

  describe "#deliver_to_automate" do
    before(:each) do
      allow(request).to receive(:approved?).and_return(true)
    end

    context "automation entry point available" do
      before(:each) do
        FactoryGirl.create(:resource_action, :action       => 'Reconfigure',
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
          :attrs            => task.options[:dialog].merge("request" => task.request_type),
          :user_id          => user.id,
          :miq_group_id     => user.current_group_id,
          :tenant_id        => user.current_tenant.id,
        }
        expect(user.current_tenant).to be_truthy
        expect(MiqQueue).to receive(:put).with(
          :class_name  => 'MiqAeEngine',
          :method_name => 'deliver',
          :args        => [automate_args],
          :role        => 'automate',
          :zone        => nil,
          :task_id     => "service_reconfigure_task_#{task.id}")
        task.deliver_to_automate
      end

      it "updates the task state to pending" do
        allow(MiqQueue).to receive(:put)
        expect(task).to receive(:update_and_notify_parent).with(
          :state   => 'pending',
          :status  => 'Ok',
          :message => 'Automation Starting')
        task.deliver_to_automate
      end
    end

    context "automation entry point missing" do
      it "updates the task state to finished" do
        expect(task).to receive(:update_and_notify_parent).with(
          :state   => 'finished',
          :status  => 'Ok',
          :message => 'Service Reconfigure completed')
        task.deliver_to_automate
      end
    end
  end
end
