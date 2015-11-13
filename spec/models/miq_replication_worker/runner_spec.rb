require "spec_helper"

describe MiqReplicationWorker::Runner do
  before do
    MiqReplicationWorker::Runner.any_instance.stub(:worker_initialization)
    @worker = MiqReplicationWorker::Runner.new
  end

  context "testing rubyrep_alive?" do
    before do
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
    it "should be alive if heartbeat within threshold" do
      @worker.stub(:child_process_last_heartbeat => 1.second.ago.utc)
      expect(@worker.child_process_recently_active?).to be_true
    end

    it "should not be alive if heartbeat beyond threshold" do
      @worker.stub(:child_process_last_heartbeat => 6.minutes.ago.utc)
      expect(@worker.child_process_recently_active?).to be_false
    end
  end
end
