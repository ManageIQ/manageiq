describe MiqWorker::Runner do
  context "#start" do
    before do
      @worker_base = MiqWorker::Runner.new
      allow(@worker_base).to receive(:worker_initialization)
      allow(@worker_base).to receive(:prepare)
    end

    it "SIGINT" do
      allow(@worker_base).to receive(:run).and_raise(Interrupt)
      expect(@worker_base).to receive(:do_exit)
      @worker_base.start
    end

    it "SIGTERM" do
      allow(@worker_base).to receive(:run).and_raise(SignalException, "SIGTERM")
      expect(@worker_base).to receive(:do_exit)
      @worker_base.start
    end

    it "Handles exception TemporaryFailure" do
      allow(@worker_base).to receive(:heartbeat).and_raise(MiqWorker::Runner::TemporaryFailure)
      expect(@worker_base).to receive(:recover_from_temporary_failure)
      allow(@worker_base).to receive(:do_gc).and_raise(RuntimeError, "Done")
      expect { @worker_base.start }.to raise_error(RuntimeError, "Done")
    end

    it "unhandled signal SIGALRM" do
      allow(@worker_base).to receive(:run).and_raise(SignalException, "SIGALRM")
      expect { @worker_base.start }.to raise_error(SignalException, "SIGALRM")
    end
  end
end
