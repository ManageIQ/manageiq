require "spec_helper"

require "workers/replication_worker"

describe ReplicationWorker do
  before(:each) do
    ReplicationWorker.any_instance.stub(:worker_initialization)
    @worker = ReplicationWorker.new
  end

  context "testing rubyrep_alive?" do
    before(:each) do
      Process.stub(:waitpid2)
      @worker.stub(:child_process_recently_active?).and_return(true)
      @worker.instance_variable_set(:@pid, 123)
    end

    it "should be alive if process is alive" do
      MiqProcess.stub(:state).and_return(:sleeping)
      expect(@worker.rubyrep_alive?).to be_true
    end

    it "should not be alive if process is zombie" do
      MiqProcess.stub(:state).and_return(:zombie)
      expect(@worker.rubyrep_alive?).to be_false
    end
  end

  context "testing child process heartbeat" do
    before(:each) do
      FileUtils.touch('/tmp/rubyrep_hb')
    end

    it "should be alive if heartbeat within threshold" do
      Timecop.freeze(Time.now.utc)

      expect(@worker.child_process_recently_active?).to be_true
    end

    it "should not be alive if heartbeat beyond threshold" do
      Timecop.freeze(301.seconds.from_now.utc)

      expect(@worker.child_process_recently_active?).to be_false
    end
  end
end
