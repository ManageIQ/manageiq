require "spec_helper"
require Rails.root.join("db/migrate/20111230141215_remove_automation_requests_and_tasks.rb")

describe RemoveAutomationRequestsAndTasks do
  migration_context :up do
    let (:request4_stub)             { migration_stub(:AutomationRequestV4) }
    let (:request_stub)              { migration_stub(:AutomationRequest) }
    let (:user_stub)                 { migration_stub(:User) }
    let (:task4_stub)                { migration_stub(:AutomationTaskV4) }
    let (:task_stub)                 { migration_stub(:AutomationTask) }

    # Common setup
    before(:each) do
      @user = user_stub.create!(
        :name   => 'John Doe',
        :userid => 'jdoe'
      )
      @user_id = @user.id

      @a_request = request_stub.create!(
        :request_type => 'should maybe be changed'
      )
      @request_id = @a_request.id

      @old_date = Time.now - 5.years
      @a_request_v4 = request4_stub.create!(
        :options     => {:miq_request_id => @request_id},
        :id          => 999,
        :description => 'should be dropped',
        :created_on  => @old_date,
        :state       => 'Kansas', # I know, it's a joke...
        :userid      => 'jdoe'
      )
    end

    it "converts AutomationRequestV4 records to AutomationRequests" do
      migrate

      @a_request.reload
      @a_request.id.should_not         == 999
      @a_request.description.should be_nil
      @a_request.created_on.should_not == @old_date
      @a_request.id.should             == @request_id
      @a_request.request_type.should   == 'automation'
      @a_request.request_state.should  == 'Kansas'
      @a_request.requester_name.should == 'jdoe'
      @a_request.requester_id.should   == @user_id
    end

    it "migrates AutomationTaskV4 records to AutomationTasks" do
      a_task_v4 = task4_stub.create!(
        :automation_request_id => @a_request_v4.id,
        :message               => 'should persist',
        :created_on            => @old_date,
        :userid                => 'stays'
      )

      migrate

      task = task_stub.find_by_miq_request_id(@request_id)
      task.request_type.should   == 'automation'
      task.message.should        == 'should persist'
      task.created_on.should_not == @old_date
      task.userid.should         == 'stays'
    end
  end
end
