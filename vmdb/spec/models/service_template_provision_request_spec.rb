require "spec_helper"

describe ServiceTemplateProvisionRequest do
  context "with multiple tasks" do
    before(:each) do
      User.any_instance.stub(:role).and_return("admin")
      @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
      UiTaskSet.stub(:find_by_name).and_return(@approver)

      @request   = FactoryGirl.create(:service_template_provision_request, :description => 'Service Request', :userid => @user.userid)

      @task_1    = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 1'         , :userid => @user.userid, :status => "Ok",:state => "pending", :miq_request_id => @request.id, :request_type => "clone_to_service")
      @task_1_1  = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 1 - 1'     , :userid => @user.userid, :status => "Ok",:state => "pending", :miq_request_id => @request.id, :request_type => "clone_to_service")
      @task_2    = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 2'         , :userid => @user.userid, :status => "Ok",:state => "pending", :miq_request_id => @request.id, :request_type => "clone_to_service")
      @task_2_1  = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 2 - 1'     , :userid => @user.userid, :status => "Ok",:state => "pending", :miq_request_id => @request.id, :request_type => "clone_to_service")

      @task_1.miq_request_tasks << @task_1_1
      @task_2.miq_request_tasks << @task_2_1
    end

    it "update_request_status - no message" do
      expect(@request.message).to eq("Service_Template_Provisioning - Request Created")
      @request.update_request_status
      expect(@request.message).to eq("Pending = 4")
    end

    it "update_request_status with message override" do
      expect(@request.message).to eq("Service_Template_Provisioning - Request Created")
      @request.update_attribute(:options, :user_message => "New test message")
      @request.update_request_status
      expect(@request.message).to eq("New test message")
    end

    it "pending state" do
      @request.update_request_status
      @request.message.should == "Pending = 4"
      @request.state.should   == "pending"
      @request.status.should  == "Ok"
    end

    it "queued state" do
      @task_1_1.update_and_notify_parent({:state => "queued", :status => "Ok", :message => "Test Message"})
      @request.reload
      @request.message.should == "Pending = 2; Queued = 2"
      @request.state.should   == "active"
      @request.status.should  == "Ok"
    end

    it "all queued state" do
      @task_1_1.update_and_notify_parent({:state => "queued", :status => "Ok", :message => "Test Message"})
      @task_2_1.update_and_notify_parent({:state => "queued", :status => "Ok", :message => "Test Message"})
      @request.reload
      @request.message.should == "Queued = 4"
      @request.state.should   == "queued"
      @request.status.should  == "Ok"
    end

    it "active state" do
      @task_1_1.update_and_notify_parent({:state => "active", :status => "Ok", :message => "Test Message"})
      @request.reload
      @request.message.should == "Active = 2; Pending = 2"
      @request.state.should   == "active"
      @request.status.should  == "Ok"
    end

    it "partial tasks finished" do
      @task_1_1.update_and_notify_parent({:state => "finished", :status => "Ok", :message => "Test Message"})
      @request.reload
      @request.message.should == "Finished = 2; Pending = 2"
      @request.state.should   == "active"
      @request.status.should  == "Ok"
    end

    it "finished state" do
      @task_1_1.update_and_notify_parent({:state => "finished", :status => "Ok", :message => "Test Message"})
      @task_2_1.update_and_notify_parent({:state => "finished", :status => "Ok", :message => "Test Message"})
      @request.reload
      @request.message.should == "Request complete"
      @request.state.should   == "finished"
      @request.status.should  == "Ok"
    end

    it "active with error state" do
      @task_1_1.update_and_notify_parent({:state => "active", :status => "Error", :message => "Error Message"})
      @request.reload
      @request.message.should == "Active = 2; Pending = 2"
      @request.state.should   == "active"
      @request.status.should  == "Error"
    end

    it "partial finish with error state" do
      @task_1_1.update_and_notify_parent({:state => "finished", :status => "Error", :message => "Error Message"})
      @request.reload
      @request.message.should == "Finished = 2; Pending = 2"
      @request.state.should   == "active"
      @request.status.should  == "Error"
    end

    it "finished with errors state" do
      @task_1_1.update_and_notify_parent({:state => "finished", :status => "Error", :message => "Error Message"})
      @task_2_1.update_and_notify_parent({:state => "finished", :status => "Ok", :message => "Test Message"})
      @request.reload
      @request.message.should == "Request completed with errors"
      @request.state.should   == "finished"
      @request.status.should  == "Error"
    end

    it "generic service do_request" do
      lambda { @task_1_1.do_request }.should_not raise_error
      @task_1_1.state.should == 'provisioned'
    end

  end
end
