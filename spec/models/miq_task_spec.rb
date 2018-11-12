describe MiqTask do
  context "when I add an MiqTask" do
    let(:miq_task) { FactoryGirl.create(:miq_task_plain) }

    it "should initialize properly" do
      expect(miq_task.state).to eq(MiqTask::STATE_INITIALIZED)
      expect(miq_task.status).to eq(MiqTask::STATUS_OK)
      expect(miq_task.message).to eq(MiqTask::DEFAULT_MESSAGE)
      expect(miq_task.userid).to eq(MiqTask::DEFAULT_USERID)
    end

    it "should respond to update_status class method properly" do
      state   = MiqTask::STATE_QUEUED
      status  = MiqTask::STATUS_OK
      message = 'This is only a class test'
      MiqTask.update_status(miq_task.id, state, status, message)
      miq_task.reload
      expect(miq_task.state).to eq(state)
      expect(miq_task.status).to eq(status)
      expect(miq_task.message).to eq(message)
    end

    it "should respond to update_status instance method properly" do
      state   = MiqTask::STATE_QUEUED
      status  = MiqTask::STATUS_OK
      message = 'This is only a test'
      miq_task.update_status(state, status, message)
      expect(miq_task.state).to eq(state)
      expect(miq_task.status).to eq(status)
      expect(miq_task.message).to eq(message)
    end

    it "should update context upon request" do
      context = {:a => 1, :b => 2}
      miq_task.update_context(context)
      expect(miq_task.context_data).to eq(context)
    end

    it "should respond to info instance method properly" do
      message      = "Hello World"
      pct_complete = 19
      miq_task.info(message, pct_complete)
      expect(miq_task.message).to eq(message)
      expect(miq_task.pct_complete).to eq(pct_complete)
    end

    it "should respond to info class method properly" do
      message      = "Goodbye World"
      pct_complete = 29
      MiqTask.info(miq_task.id, message, pct_complete)
      miq_task.reload
      expect(miq_task.message).to eq(message)
      expect(miq_task.pct_complete).to eq(pct_complete)
    end

    it "should respond to warn instance method properly" do
      message      = "There may be a fire on your floor"
      miq_task.warn(message)
      expect(miq_task.message).to eq(message)
      expect(miq_task.status).to eq(MiqTask::STATUS_WARNING)
    end

    it "should respond to warn class method properly" do
      message      = "There may be a fire on your floor (class)"
      MiqTask.warn(miq_task.id, message)
      miq_task.reload
      expect(miq_task.message).to eq(message)
      expect(miq_task.status).to eq(MiqTask::STATUS_WARNING)
    end

    it "should respond to error instance method properly" do
      message      = "Red Alert"
      miq_task.error(message)
      expect(miq_task.message).to eq(message)
      expect(miq_task.status).to eq(MiqTask::STATUS_ERROR)
    end

    it "should respond to error class method properly" do
      message      = "Red Alert (class)"
      MiqTask.error(miq_task.id, message)
      miq_task.reload
      expect(miq_task.message).to eq(message)
      expect(miq_task.status).to eq(MiqTask::STATUS_ERROR)
    end

    it "should respond to state_initialized instance method properly" do
      miq_task.state_initialized
      expect(miq_task.state).to eq(MiqTask::STATE_INITIALIZED)
    end

    it "should respond to state_initialized class method properly" do
      MiqTask.state_initialized(miq_task.id)
      miq_task.reload
      expect(miq_task.state).to eq(MiqTask::STATE_INITIALIZED)
    end

    it "should respond to state_queued instance method properly" do
      miq_task.state_queued
      expect(miq_task.state).to eq(MiqTask::STATE_QUEUED)
    end

    it "should respond to state_queued class method properly" do
      MiqTask.state_queued(miq_task.id)
      miq_task.reload
      expect(miq_task.state).to eq(MiqTask::STATE_QUEUED)
    end

    it "should respond to state_active instance method properly" do
      miq_task.state_active
      expect(miq_task.state).to eq(MiqTask::STATE_ACTIVE)
    end

    it "should respond to state_active class method properly" do
      MiqTask.state_active(miq_task.id)
      miq_task.reload
      expect(miq_task.state).to eq(MiqTask::STATE_ACTIVE)
    end

    it "should respond to state_finished instance method properly" do
      miq_task.state_finished
      expect(miq_task.state).to eq(MiqTask::STATE_FINISHED)
    end

    it "should respond to state_finished class method properly" do
      MiqTask.state_finished(miq_task.id)
      miq_task.reload
      expect(miq_task.state).to eq(MiqTask::STATE_FINISHED)
    end

    it "should get/set task_results properly" do
      results = {:a => 1, :b => 2}
      miq_task.task_results = results
      miq_task.save
      expect(miq_task.task_results).to eq(results)
    end

    it "should queue callback properly" do
      state   = MiqTask::STATE_QUEUED
      message = 'Message for testing: queue_callback'
      result  = {:a => 1, :b => 2}
      miq_task.queue_callback(state, 'ok', message, result)
      expect(miq_task.state).to eq(state)
      expect(miq_task.status).to eq(MiqTask::STATUS_OK)
      expect(miq_task.message).to eq(MiqTask::MESSAGE_TASK_COMPLETED_SUCCESSFULLY)
      expect(miq_task.task_results).to eq(result)

      status  = MiqTask::STATUS_ERROR
      miq_task.queue_callback(state, status, "", result)
      expect(miq_task.state).to eq(state)
      expect(miq_task.status).to eq(status)
      expect(miq_task.message).to eq(MiqTask::MESSAGE_TASK_COMPLETED_UNSUCCESSFULLY)
      expect(miq_task.task_results).to eq(result)

      result  = {:c => 1, :d => 2}
      miq_task.queue_callback(state, status, message, result)
      expect(miq_task.state).to eq(state)
      expect(miq_task.status).to eq(status)
      expect(miq_task.message).to eq(message)
      expect(miq_task.task_results).to eq(result)
    end

    it "should queue callback on exceptions properly" do
      state   = MiqTask::STATE_QUEUED
      message = 'Message for testing: queue_callback_on_exceptions'
      result  = {:a => 1, :b => 2}
      miq_task.queue_callback_on_exceptions(state, 'ok', message, result)
      expect(miq_task.state).to eq(MiqTask::STATE_INITIALIZED)
      expect(miq_task.status).to eq(MiqTask::STATUS_OK)
      expect(miq_task.message).to eq(MiqTask::DEFAULT_MESSAGE)
      expect(miq_task.task_results).to be_nil

      miq_task.queue_callback_on_exceptions(state, "MAYDAY", message, result)
      expect(miq_task.state).to eq(state)
      expect(miq_task.status).to eq(MiqTask::STATUS_ERROR)
      expect(miq_task.message).to eq(message)
      expect(miq_task.task_results).to eq(result)
    end

    it "should properly process MiqTask#generic_action_with_callback" do
      zone = FactoryGirl.create(:zone)
      allow(MiqServer).to receive(:my_zone).and_return(zone.name)
      opts = {
        :action => 'Feed',
        :userid => 'Flintstone'
      }
      qopts = {
        :class_name  => "MyClass",
        :method_name => "my_method",
        :args        => [1, 2, 3]
      }
      tid = MiqTask.generic_action_with_callback(opts, qopts)
      task = MiqTask.find_by(:id => tid)
      expect(task.state).to eq(MiqTask::STATE_QUEUED)
      expect(task.status).to eq(MiqTask::STATUS_OK)
      expect(task.userid).to eq("Flintstone")
      expect(task.name).to eq("Feed")
      expect(task.message).to eq("Queued the action: [#{task.name}] being run for user: [#{task.userid}]")

      expect(MiqQueue.count).to eq(1)
      message = MiqQueue.first
      expect(message.class_name).to eq("MyClass")
      expect(message.method_name).to eq("my_method")
      expect(message.args).to eq([1, 2, 3])
      expect(message.zone).to eq(zone.name)
      expect(message.miq_task_id).to eq(tid)
    end
  end

  context "when there are multiple MiqTasks" do
    let(:miq_task1) { FactoryGirl.create(:miq_task_plain) }
    let(:miq_task2) { FactoryGirl.create(:miq_task_plain) }
    let(:miq_task3) { FactoryGirl.create(:miq_task_plain) }
    let(:zone)      { FactoryGirl.create(:zone) }
    before do
      allow(MiqServer).to receive(:my_zone).and_return(zone.name)
    end

    it "should queue up deletes when calling MiqTask.delete_by_id" do
      MiqTask.delete_by_id([miq_task1.id, miq_task3.id])
      expect(MiqQueue.count).to eq(1)
      message = MiqQueue.first

      expect(message.class_name).to eq("MiqTask")
      expect(message.method_name).to eq("destroy")
      expect(message.args).to        be_kind_of(Array)
      expect(message.args.length).to eq(1)
      expect(message.args.first).to match_array([miq_task1.id, miq_task3.id])
      expect(message.zone).to eq(zone.name)
    end

    it "should queue up proper deletes when calling MiqTask.delete_older" do
      Timecop.travel(10.minutes.ago) { miq_task2.state_queued }
      Timecop.travel(12.minutes.ago) { miq_task3.state_queued }
      date_5_minutes_ago = 5.minutes.ago.utc
      condition = "name LIKE 'name LIKE 'Performance rollup for %''"
      MiqTask.delete_older(date_5_minutes_ago, condition)

      expect(MiqQueue.count).to eq(1)
      message = MiqQueue.first

      expect(message.class_name).to eq("MiqTask")
      expect(message.method_name).to eq("destroy_older_by_condition")
      expect(message.args).to        be_kind_of(Array)
      expect(message.args.length).to eq(2)
      expect(message.args.first).to eq(date_5_minutes_ago)
      expect(message.args.second).to eq(condition)
      expect(message.zone).to eq(zone.name)

      message.destroy

      date_11_minutes_ago = 11.minutes.ago.utc
      MiqTask.delete_older(date_11_minutes_ago, nil)

      expect(MiqQueue.count).to eq(1)
      message = MiqQueue.first

      expect(message.class_name).to eq("MiqTask")
      expect(message.method_name).to eq("destroy_older_by_condition")
      expect(message.args).to        be_kind_of(Array)
      expect(message.args.length).to eq(2)
      expect(message.args.first).to eq(date_11_minutes_ago)
      expect(message.args.second).to be nil
      expect(message.zone).to eq(zone.name)
    end
  end

  describe '#results_ready?' do
    let(:miq_task) { FactoryGirl.create(:miq_task_plain) }
    it 'returns false when task_results are missing' do
      expect(miq_task.task_results).to be_blank
      expect(miq_task.status).to eq(MiqTask::STATUS_OK)
      expect(miq_task.results_ready?).to be_falsey
    end
    it 'returns false when status is error' do
      miq_task.error('bang')
      expect(miq_task.results_ready?).to be_falsey
    end
    it 'returns true when status is ok and results are not blank' do
      miq_task.task_results = 'x'
      expect(miq_task.results_ready?).to be_truthy
    end
  end

  context "before_destroy callback" do
    it "destroys miq_task record if there is no job associated with it and Task is not active" do
      miq_task = FactoryGirl.create(:miq_task_plain)
      miq_task.update_attributes!(:state => MiqTask::STATE_QUEUED)
      miq_task.destroy
      expect(MiqTask.count).to eq 0
    end

    it "doesn't destroy miq_task and associated job if job is active" do
      expect(MiqTask.count).to eq 0
      job = Job.create_job("VmScan")
      job.update_attributes!(:state => "active")
      expect(MiqTask.count).to eq 1
      MiqTask.first.destroy
      expect(MiqTask.count).to eq 1
      expect(Job.count).to eq 1
    end

    it "doesn't destroy miq_task if task is active" do
      expect(MiqTask.count).to eq 0
      miq_task = FactoryGirl.create(:miq_task_plain)
      expect(MiqTask.count).to eq 1
      miq_task.update_attributes!(:state => MiqTask::STATE_ACTIVE)
      MiqTask.first.destroy
      expect(MiqTask.count).to eq 1
    end

    it "destroys miq_task record and job record if job associated with it 'finished'" do
      expect(MiqTask.count).to eq 0
      job = Job.create_job("VmScan")
      job.update_attributes!(:state => "finished")
      expect(MiqTask.count).to eq 1
      MiqTask.first.destroy
      expect(MiqTask.count).to eq 0
      expect(Job.count).to eq 0
    end

    it "destroys miq_task record and job record if job associated with it not started yet" do
      expect(MiqTask.count).to eq 0
      job = Job.create_job("VmScan")
      job.update_attributes!(:state => "waiting_to_start")
      expect(MiqTask.count).to eq 1
      MiqTask.first.destroy
      expect(MiqTask.count).to eq 0
      expect(Job.count).to eq 0
    end
  end

  context "before save callback" do
    describe "#started" do
      let(:task) { FactoryGirl.create(:miq_task_plain) }

      it "initilizes 'started_on' attribute if task become Active " do
        expect(task.started_on).to be nil
        Timecop.freeze do
          task.update_attributes!(:state => MiqTask::STATE_ACTIVE)
          expect(task.started_on).to eq Time.now.utc
        end
      end
    end
  end

  describe "#update_status" do
    let(:miq_task) { FactoryGirl.create(:miq_task_plain) }

    context "to 'Active' state" do
      it "sets 'started_on => Time.now.utc' if 'started_on' is nil" do
        Timecop.freeze do
          expect(miq_task.started_on).to be nil
          miq_task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "")
          expect(miq_task.started_on).to eq Time.now.utc
        end
      end

      it "does not set 'started_on' if passed state is not 'active'" do
        miq_task.update_status("Any state", MiqTask::STATUS_OK, "")
        expect(miq_task.started_on).to be nil
      end

      it "does not changed 'started_on' if task already has 'started-on' attribute set" do
        some_time = Time.now.utc - 5.hours
        miq_task.update_attributes!(:started_on => some_time)
        miq_task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "")
        expect(miq_task.started_on).to eq some_time
      end

      it "sets 'miq_server' association" do
        server = EvmSpecHelper.local_miq_server
        miq_task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "")
        expect(miq_task.miq_server.id).to eq server.id
      end
    end
  end

  describe "#state_active" do
    let(:miq_task) { FactoryGirl.create(:miq_task_plain) }

    it "sets 'started_on => Time.now.utc' if 'started_on' is nil" do
      Timecop.freeze do
        expect(miq_task.started_on).to be nil
        miq_task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "")
        expect(miq_task.started_on).to eq Time.now.utc
      end
    end

    it "does not changed 'started_on' if task already has 'started-on' attribute set" do
      some_time = Time.now.utc - 5.hours
      miq_task.update_attributes!(:started_on => some_time)
      miq_task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "")
      expect(miq_task.started_on).to eq some_time
    end

    it "sets 'miq_server' association" do
      server = EvmSpecHelper.local_miq_server
      miq_task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "")
      expect(miq_task.miq_server.id).to eq server.id
    end
  end

  describe ".update_status_for_timed_out_active_tasks" do
    let(:timeout) { "1.hour" }
    before do
      stub_settings(:task => {:active_task_timeout => timeout})
    end

    context "task does not linked to job" do
      let(:miq_task) { FactoryGirl.create(:miq_task_plain) }

      context "task is active" do
        before do
          miq_task.update_attributes(:state => MiqTask::STATE_ACTIVE)
        end

        it "updates status to 'Error' for timed out task" do
          miq_task.update_attributes(:updated_on => miq_task.updated_on - timeout.to_i_with_method)
          expect(miq_task.status).not_to eq MiqTask::STATUS_ERROR
          MiqTask.update_status_for_timed_out_active_tasks
          miq_task.reload
          expect(miq_task.status).to eq MiqTask::STATUS_ERROR
          expect(miq_task.message).to include("not active for more than 3600 seconds")
        end

        it "does not update status if task not timed out" do
          MiqTask.update_status_for_timed_out_active_tasks
          miq_task.reload
          expect(miq_task.status).not_to eq MiqTask::STATUS_ERROR
        end
      end

      context "task is not active" do
        it "does not update status to 'Error' if task state is 'Finished'" do
          miq_task.update_attributes(:state      => MiqTask::STATE_FINISHED,
                                     :updated_on => miq_task.updated_on - timeout.to_i_with_method)
          MiqTask.update_status_for_timed_out_active_tasks
          miq_task.reload
          expect(miq_task.status).not_to eq MiqTask::STATUS_ERROR
        end

        it "does not update status to 'Error' if task state is 'Queued'" do
          miq_task.update_attributes(:state      => MiqTask::STATE_QUEUED,
                                     :updated_on => miq_task.updated_on - timeout.to_i_with_method)
          MiqTask.update_status_for_timed_out_active_tasks
          miq_task.reload
          expect(miq_task.status).not_to eq MiqTask::STATUS_ERROR
        end
      end
    end

    context "task linked to job" do
      let(:miq_task) do
        job = Job.create_job("VmScan")
        job.miq_task
      end

      it "does not update status to 'Error'" do
        miq_task.update_attributes(:state      => MiqTask::STATE_ACTIVE,
                                   :updated_on => miq_task.updated_on - timeout.to_i_with_method)
        MiqTask.update_status_for_timed_out_active_tasks
        miq_task.reload
        expect(miq_task.status).not_to eq MiqTask::STATUS_ERROR
      end
    end
  end

  describe ".destroy_older_by_condition" do
    before do
      create_test_task("Task1", MiqTask::STATUS_OK, 10.minutes.ago)
      create_test_task("Task12", MiqTask::STATUS_ERROR, 20.minutes.ago)
      create_test_task("Task3", MiqTask::STATUS_ERROR, 30.minutes.ago)
      create_test_task("Task4", MiqTask::STATUS_WARNING, 40.minutes.ago)
    end

    it "destroys task older than passed date and nil as filtering condition" do
      MiqTask.destroy_older_by_condition(15.minutes.ago, nil)
      expect(MiqTask.count).to eq 1
    end

    it "destroys task filtered by passed condition and older than passed date" do
      MiqTask.destroy_older_by_condition(15.minutes.ago, ["status=? AND name LIKE ?", MiqTask::STATUS_ERROR, "Task1%"])
      expect(MiqTask.count).to eq 3
    end
  end

  describe "#task_results" do
    it "forces UTF-8 encoding" do
      task = FactoryGirl.create(
        :miq_task,
        :binary_blob => BinaryBlob.new(
          :name      => "task_results",
          :data_type => "YAML",
          :binary    => YAML.dump("\xC3\xA4".force_encoding("ASCII-8BIT"))
        )
      )

      expect(task.task_results).to eq("ä")
    end
  end

  describe "#task_results=" do
    it "forces UTF-8 encoding" do
      task = FactoryGirl.create(:miq_task, :task_results => "\xC3\xA4".force_encoding("ASCII-8BIT"))

      expect(task.task_results).to eq("ä")
    end
  end

  private

  def create_test_task(name, status, updated)
    Timecop.travel(updated) do
      FactoryGirl.create(:miq_task_plain).update_attributes(:state  => MiqTask::STATE_FINISHED,
                                                            :status => status,
                                                            :name   => name)
    end
  end
end
