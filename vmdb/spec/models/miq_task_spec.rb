require "spec_helper"

describe MiqTask do
  context "when I add an MiqTask" do
    before(:each) do
      @miq_task = FactoryGirl.create(:miq_task_plain)
    end

    it "should initialize properly" do
      @miq_task.state.should   == MiqTask::STATE_INITIALIZED
      @miq_task.status.should  == MiqTask::STATUS_OK
      @miq_task.message.should == MiqTask::DEFAULT_MESSAGE
      @miq_task.userid.should  == MiqTask::DEFAULT_USERID
    end

    it "should respond to update_status class method properly" do
      state   = MiqTask::STATE_QUEUED
      status  = MiqTask::STATUS_OK
      message = 'This is only a class test'
      MiqTask.update_status(@miq_task.id, state, status, message)
      @miq_task.reload
      @miq_task.state.should   == state
      @miq_task.status.should  == status
      @miq_task.message.should == message
    end

    it "should respond to update_status instance method properly" do
      state   = MiqTask::STATE_QUEUED
      status  = MiqTask::STATUS_OK
      message = 'This is only a test'
      @miq_task.update_status(state, status, message)
      @miq_task.state.should   == state
      @miq_task.status.should  == status
      @miq_task.message.should == message

      lambda { @miq_task.update_status("FOO", status, message) }.should raise_error(ActiveRecord::RecordInvalid)
      lambda { @miq_task.update_status(state, "FOO",  message) }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should trim long message to 255" do
      message = ("So there I was sitting in a rabbit's suit" * 100).freeze
      @miq_task.message = message
      @miq_task.message.length.should == 255
      @miq_task.message[252,3].should == "..."

      @miq_task.update_attributes(:message => message)
      @miq_task.message.length.should == 255
      @miq_task.message[252,3].should == "..."
    end

    it "should update context upon request" do
      context = { :a => 1, :b => 2 }
      @miq_task.update_context(context)
      @miq_task.context_data.should == context
    end

    it "should respond to info instance method properly" do
      message      = "Hello World"
      pct_complete = 19
      @miq_task.info(message, pct_complete)
      @miq_task.message.should      == message
      @miq_task.pct_complete.should == pct_complete
    end

    it "should respond to info class method properly" do
      message      = "Goodbye World"
      pct_complete = 29
      MiqTask.info(@miq_task.id, message, pct_complete)
      @miq_task.reload
      @miq_task.message.should      == message
      @miq_task.pct_complete.should == pct_complete
    end

    it "should respond to warn instance method properly" do
      message      = "There may be a fire on your floor"
      @miq_task.warn(message)
      @miq_task.message.should == message
      @miq_task.status.should  == MiqTask::STATUS_WARNING
    end

    it "should respond to warn class method properly" do
      message      = "There may be a fire on your floor (class)"
      MiqTask.warn(@miq_task.id, message)
      @miq_task.reload
      @miq_task.message.should == message
      @miq_task.status.should  == MiqTask::STATUS_WARNING
    end

    it "should respond to error instance method properly" do
      message      = "Red Alert"
      @miq_task.error(message)
      @miq_task.message.should == message
      @miq_task.status.should  == MiqTask::STATUS_ERROR
    end

    it "should respond to error class method properly" do
      message      = "Red Alert (class)"
      MiqTask.error(@miq_task.id, message)
      @miq_task.reload
      @miq_task.message.should == message
      @miq_task.status.should  == MiqTask::STATUS_ERROR
    end

    it "should respond to state_initialized instance method properly" do
      @miq_task.state_initialized
      @miq_task.state.should == MiqTask::STATE_INITIALIZED
    end

    it "should respond to state_initialized class method properly" do
      MiqTask.state_initialized(@miq_task.id)
      @miq_task.reload
      @miq_task.state.should == MiqTask::STATE_INITIALIZED
    end

    it "should respond to state_queued instance method properly" do
      @miq_task.state_queued
      @miq_task.state.should == MiqTask::STATE_QUEUED
    end

    it "should respond to state_queued class method properly" do
      MiqTask.state_queued(@miq_task.id)
      @miq_task.reload
      @miq_task.state.should == MiqTask::STATE_QUEUED
    end

    it "should respond to state_active instance method properly" do
      @miq_task.state_active
      @miq_task.state.should == MiqTask::STATE_ACTIVE
    end

    it "should respond to state_active class method properly" do
      MiqTask.state_active(@miq_task.id)
      @miq_task.reload
      @miq_task.state.should == MiqTask::STATE_ACTIVE
    end

    it "should respond to state_finished instance method properly" do
      @miq_task.state_finished
      @miq_task.state.should == MiqTask::STATE_FINISHED
    end

    it "should respond to state_finished class method properly" do
      MiqTask.state_finished(@miq_task.id)
      @miq_task.reload
      @miq_task.state.should == MiqTask::STATE_FINISHED
    end

    it "should get/set task_results properly" do
      results = { :a => 1, :b => 2 }
      @miq_task.task_results = results
      @miq_task.save
      @miq_task.task_results.should == results
    end

    it "should cleanup_log properly" do
      l = FactoryGirl.create(:log_file, :miq_task_id => @miq_task.id)
      @miq_task.reload
      @miq_task.log_file.should == l

      @miq_task.cleanup_log
      @miq_task.reload
      @miq_task.log_file.should be_nil
      LogFile.count.should == 0
    end

    it "should get log_data properly" do
      log_data = "test log data" * 100000
      l = FactoryGirl.create(:log_file, :miq_task_id => @miq_task.id)
      l.binary_blob = FactoryGirl.create(:binary_blob, :name => "logs", :data_type => "zip")
      l.binary_blob.binary = log_data.dup # BinaryBlob#binary= method destroys the input data

      @miq_task.reload
      @miq_task.log_data.should == log_data
    end

    it "should queue callback properly" do
      state   = MiqTask::STATE_QUEUED
      message = 'Message for testing: queue_callback'
      result  = { :a => 1, :b => 2 }
      @miq_task.queue_callback(state, 'ok', message, result)
      @miq_task.state.should        == state
      @miq_task.status.should       == MiqTask::STATUS_OK
      @miq_task.message.should      == MiqTask::MESSAGE_TASK_COMPLETED_SUCCESSFULLY
      @miq_task.task_results.should == result

      status  = MiqTask::STATUS_ERROR
      @miq_task.queue_callback(state, status, "", result)
      @miq_task.state.should        == state
      @miq_task.status.should       == status
      @miq_task.message.should      == MiqTask::MESSAGE_TASK_COMPLETED_UNSUCCESSFULLY
      @miq_task.task_results.should == result

      result  = { :c => 1, :d => 2 }
      @miq_task.queue_callback(state, status, message, result)
      @miq_task.state.should        == state
      @miq_task.status.should       == status
      @miq_task.message.should      == message
      @miq_task.task_results.should == result
    end

    it "should queue callback on exceptions properly" do
      state   = MiqTask::STATE_QUEUED
      message = 'Message for testing: queue_callback_on_exceptions'
      result  = { :a => 1, :b => 2 }
      @miq_task.queue_callback_on_exceptions(state, 'ok', message, result)
      @miq_task.state.should        == MiqTask::STATE_INITIALIZED
      @miq_task.status.should       == MiqTask::STATUS_OK
      @miq_task.message.should      == MiqTask::DEFAULT_MESSAGE
      @miq_task.task_results.should be_nil

      @miq_task.queue_callback_on_exceptions(state, "MAYDAY", message, result)
      @miq_task.state.should        == state
      @miq_task.status.should       == MiqTask::STATUS_ERROR
      @miq_task.message.should      == message
      @miq_task.task_results.should == result
    end

    it "should properly process MiqTask#generic_action_with_callback" do
      zone = 'New York'
      MiqServer.stub(:my_zone).and_return(zone)
      opts = {
        :action       => 'Feed',
        :userid       => 'Flintstone'
      }
      qopts = {
        :class_name   => "MyClass",
        :method_name  => "my_method",
        :args         => [1, 2, 3]
      }
      tid = MiqTask.generic_action_with_callback(opts, qopts)
      task = MiqTask.find_by_id(tid)
      task.state.should   == MiqTask::STATE_QUEUED
      task.status.should  == MiqTask::STATUS_OK
      task.userid.should  == "Flintstone"
      task.name.should    == "Feed"
      task.message.should == "Queued the action: [#{task.name}] being run for user: [#{task.userid}]"

      MiqQueue.count.should == 1
      message = MiqQueue.find(:first)
      message.class_name.should  == "MyClass"
      message.method_name.should == "my_method"
      message.args.should        == [1, 2, 3]
      message.zone.should        == zone
    end
  end

  context "when there are multiple MiqTasks" do
    before(:each) do
      @miq_task1 = FactoryGirl.create(:miq_task_plain)
      @miq_task2 = FactoryGirl.create(:miq_task_plain)
      @miq_task3 = FactoryGirl.create(:miq_task_plain)
      @zone = 'New York'
      MiqServer.stub(:my_zone).and_return(@zone)
    end

    it "should queue up deletes when calling MiqTask.delete_by_id" do
      MiqTask.delete_by_id([@miq_task1.id, @miq_task3.id])
      MiqQueue.count.should == 1
      message = MiqQueue.find(:first)

      message.class_name.should  == "MiqTask"
      message.method_name.should == "destroy_all"
      message.args.should        be_kind_of(Array)
      message.args.length.should == 1
      message.args.first.should  be_kind_of(Array)
      message.args.first.length.should == 2
      str, arr = message.args.first
      str.should                 == "id in (?)"
      arr.should                 have_same_elements([@miq_task1.id, @miq_task3.id])
      message.zone.should        == @zone
    end

    it "should queue up proper deletes when calling MiqTask.delete_older" do
      Timecop.travel(10.minutes.ago) { @miq_task2.state_queued }
      Timecop.travel(12.minutes.ago) { @miq_task3.state_queued }
      MiqTask.delete_older(5.minutes.ago.utc, nil)

      MiqQueue.count.should == 1
      message = MiqQueue.find(:first)

      message.class_name.should  == "MiqTask"
      message.method_name.should == "destroy_all"
      message.args.should        be_kind_of(Array)
      message.args.length.should == 1
      message.args.first.should  be_kind_of(Array)
      message.args.first.length.should == 2
      str, arr = message.args.first
      str.should                 == "id in (?)"
      arr.should                 have_same_elements([@miq_task2.id, @miq_task3.id])
      message.zone.should        == @zone

      message.destroy

      MiqTask.delete_older(11.minutes.ago.utc, nil)

      MiqQueue.count.should == 1
      message = MiqQueue.find(:first)

      message.class_name.should  == "MiqTask"
      message.method_name.should == "destroy_all"
      message.args.should        == [["id in (?)", [@miq_task3.id]]]
      message.zone.should        == @zone
    end

  end
end
