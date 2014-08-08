require "spec_helper"

describe ServiceReconfigureTask do
  before(:each) do
    FactoryGirl.create(:ui_task_set_approver)
  end

  let(:user)     { FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred') }
  let(:template) { FactoryGirl.create(:service_template, :name => 'Test Template') }
  let(:service)  { FactoryGirl.create(:service, :name => 'Test Service', :service_template => template) }

  let(:request) do
    ServiceReconfigureRequest.create(:userid       => user.userid,
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
      ServiceReconfigureTask.base_model.should == ServiceReconfigureTask
    end
  end

  describe "#self.get_description" do
    it "returns a description based upon the source service name" do
      ServiceReconfigureTask.get_description(request).should == "Service Reconfigure for: Test Service"
    end
  end

  describe "#after_ae_delivery" do
    it "updates the task status to Ok if automation run successfully" do
      task.should_receive(:update_and_notify_parent).with(
        :state   => 'finished',
        :status  => 'Ok',
        :message => 'Service Reconfigure completed')
      task.after_ae_delivery('ok')
    end

    it "updates the task status to Error if automation encountered an error" do
      task.should_receive(:update_and_notify_parent).with(
        :state   => 'finished',
        :status  => 'Error',
        :message => 'Service Reconfigure failed')
      task.after_ae_delivery('error')
    end
  end

  describe "#after_request_task_create" do
    it "should set the task description" do
      task.after_request_task_create
      task.description.should == "Service Reconfigure for: Test Service"
    end
  end

  describe "#deliver_to_automate" do
    before(:each) do
      request.stub(:approved?).and_return(true)
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
          :user_id          => user.id
        }
        MiqQueue.should_receive(:put).with(
          :class_name  => 'MiqAeEngine',
          :method_name => 'deliver',
          :args        => [automate_args],
          :role        => 'automate',
          :zone        => nil,
          :task_id     => "service_reconfigure_task_#{task.id}")
        task.deliver_to_automate
      end

      it "updates the task state to pending" do
        MiqQueue.stub(:put)
        task.should_receive(:update_and_notify_parent).with(
          :state   => 'pending',
          :status  => 'Ok',
          :message => 'Automation Starting')
        task.deliver_to_automate
      end
    end

    context "automation entry point missing" do
      it "updates the task state to finished" do
        task.should_receive(:update_and_notify_parent).with(
          :state   => 'finished',
          :status  => 'Ok',
          :message => 'Service Reconfigure completed')
        task.deliver_to_automate
      end
    end
  end
end
