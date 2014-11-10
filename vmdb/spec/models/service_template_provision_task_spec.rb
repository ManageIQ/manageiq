require "spec_helper"

describe ServiceTemplateProvisionTask do
  context "with multiple tasks" do
    before(:each) do
      User.any_instance.stub(:role).and_return("admin")
      @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
      UiTaskSet.stub(:find_by_name).and_return(@approver)

      @request   = FactoryGirl.create(:service_template_provision_request, :description => 'Service Request', :userid => @user.userid)
      @task_0    = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 0 (Top)'   , :userid => @user.userid, :status => "Ok", :state => "pending",  :miq_request_id => @request.id, :request_type => "clone_to_service")
      @task_1    = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 1'         , :userid => @user.userid, :status => "Ok", :state => "pending",  :miq_request_id => @request.id, :request_type => "clone_to_service", :options => {:service_resource_id => FactoryGirl.create(:service_resource, :provision_index => 7, :scaling_min => 1, :scaling_max => 1, :resource_type => 'ServiceTemplate').id})
      @task_1_1  = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 1 - 1'     , :userid => @user.userid, :status => "Ok", :state => "pending",  :miq_request_id => @request.id, :request_type => "clone_to_service", :options => {:service_resource_id => FactoryGirl.create(:service_resource, :provision_index => 1, :scaling_min => 1, :scaling_max => 3, :resource_type => 'ServiceTemplate').id})
      @task_1_2  = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 1 - 2'     , :userid => @user.userid, :status => "Ok", :state => "pending",  :miq_request_id => @request.id, :request_type => "clone_to_service", :options => {:service_resource_id => FactoryGirl.create(:service_resource, :provision_index => 5, :scaling_min => 1, :scaling_max => 1, :resource_type => 'ServiceTemplate').id})
      @task_2    = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 2'         , :userid => @user.userid, :status => "Ok", :state => "pending",  :miq_request_id => @request.id, :request_type => "clone_to_service", :options => {:service_resource_id => FactoryGirl.create(:service_resource, :provision_index => 9, :scaling_min => 1, :scaling_max => 1, :resource_type => 'ServiceTemplate').id})
      @task_2_1  = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 2 - 1'     , :userid => @user.userid, :status => "Ok", :state => "pending",  :miq_request_id => @request.id, :request_type => "clone_to_service", :options => {:service_resource_id => FactoryGirl.create(:service_resource, :provision_index => 2, :scaling_min => 1, :scaling_max => 1, :resource_type => 'ServiceTemplate').id})
      @task_3    = FactoryGirl.create(:service_template_provision_task,    :description => 'Task 3'         , :userid => @user.userid, :status => "Ok", :state => "finished", :miq_request_id => @request.id, :request_type => "clone_to_service", :options => {:service_resource_id => FactoryGirl.create(:service_resource, :provision_index => 3, :scaling_min => 1, :scaling_max => 5, :resource_type => 'ServiceTemplate').id})

      @request.miq_request_tasks = [@task_0, @task_1, @task_1_1, @task_1_2, @task_2, @task_2_1]
      @task_0.miq_request_tasks  = [@task_1, @task_2, @task_3]
      @task_1.miq_request_task   =  @task_0
      @task_1.miq_request_tasks  = [@task_1_1, @task_1_2]
      @task_1_1.miq_request_task =  @task_1
      @task_1_2.miq_request_task =  @task_1
      @task_2.miq_request_task   =  @task_0
      @task_2.miq_request_tasks  = [@task_2_1]
      @task_3.miq_request_task   =  @task_0
    end

    it "service 1 child provision priority" do
      @task_1_1.provision_priority.should == 1
    end

    it "service 2 child provision priority" do
      @task_2_1.provision_priority.should == 2
    end

    it "service 1 can run now" do
      @task_1.group_sequence_run_now?.should == true
    end

    it "service 1 child 1 can run now" do
      @task_1_1.group_sequence_run_now?.should == true
    end

    it "service 1 child 2 cannot run yet" do
      @task_1_2.group_sequence_run_now?.should == false
    end

    it "service 2 cannot run yet" do
      @task_2.group_sequence_run_now?.should == false
    end

    it "service 2 child 1 cannot run yet" do
      @task_2_1.group_sequence_run_now?.should == false
    end

    it "service 3 can run now" do
      @task_3.group_sequence_run_now?.should == true
    end

    it "call task_finished" do
      @task_1_2.should_receive(:task_finished).once
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

    context "with a service" do
      before(:each) do
        @service = FactoryGirl.create(:service, :name => 'Test Service')
      end

      it "raise provisioned event" do
        @task_1_2.destination = @service
        @task_1_2.update_and_notify_parent(:state => "finished", :status => "Ok", :message => "Test Message")
        @service.ems_events.count.should == 1
        @service.ems_events.first.event_type.should == "service_provisioned"
      end
    end
  end
end
