require "spec_helper"

require "workers/replication_worker"

describe ReplicationWorker do
  before do
    ReplicationWorker.any_instance.stub(:worker_initialization)
    @worker = ReplicationWorker.new
    @hb_file = Rails.root.join('tmp/rubyrep_hb')
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
    after do
      Timecop.return
      File.delete(@hb_file) if File.exist?(@hb_file)
    end

    it "should be alive if heartbeat within threshold" do
      FileUtils.touch(@hb_file)
      expect(@worker.child_process_recently_active?).to be_true
    end

    it "should not be alive if heartbeat beyond threshold" do
      FileUtils.touch(@hb_file)

      Timecop.travel(301) do
        expect(@worker.child_process_recently_active?).to be_false
      end
    end
  end
end
