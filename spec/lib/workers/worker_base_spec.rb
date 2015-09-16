require "spec_helper"

describe MiqWorker::Runner do
  context "#start" do
    before do
      MiqWorker::Runner.any_instance.stub(:worker_initialization)
      @worker_base = MiqWorker::Runner.new
      @worker_base.stub(:prepare)
    end

    it "SIGINT" do
      @worker_base.stub(:run).and_raise(Interrupt)
      @worker_base.should_receive(:do_exit)
      @worker_base.start
    end

    it "SIGTERM" do
      @worker_base.stub(:run).and_raise(SignalException, "SIGTERM")
      @worker_base.should_receive(:do_exit)
      @worker_base.start
    end

    it "unhandled signal SIGALRM" do
      @worker_base.stub(:run).and_raise(SignalException, "SIGALRM")
      expect { @worker_base.start }.to raise_error(SignalException, "SIGALRM")
    end
  end
end
