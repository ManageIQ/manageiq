describe MiqWorker::Runner do
  context "#start" do
    before do
      allow_any_instance_of(MiqWorker::Runner).to receive(:worker_initialization)
      @worker_base = MiqWorker::Runner.new
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

    it "worker_monitor_drb caches DRbObject" do
      @worker_base.instance_variable_set(:@server, FactoryGirl.create(:miq_server, :drb_uri => "druby://127.0.0.1:123456"))
      require 'drb'
      allow(DRbObject).to receive(:new).and_return(0, 1)
      expect(@worker_base.worker_monitor_drb).to eq 0
      expect(@worker_base.worker_monitor_drb).to eq 0
    end
  end
end
