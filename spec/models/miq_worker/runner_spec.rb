RSpec.describe MiqWorker::Runner do
  context "#start" do
    before do
      allow_any_instance_of(MiqWorker::Runner).to receive(:worker_initialization)
      @worker_base = MiqWorker::Runner.new
      allow(@worker_base).to receive(:prepare)
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
      @worker_base.instance_variable_set(:@server, FactoryBot.create(:miq_server, :drb_uri => "druby://127.0.0.1:123456"))
      require 'drb'
      allow(DRbObject).to receive(:new).and_return(0, 1)
      expect(@worker_base.worker_monitor_drb).to eq 0
      expect(@worker_base.worker_monitor_drb).to eq 0
    end
  end

  context "#config_out_of_date?" do
    before do
      allow_any_instance_of(MiqWorker::Runner).to receive(:worker_initialization)
      @worker_base = MiqWorker::Runner.new
    end

    it "returns true for the first call and false for subsequent calls" do
      expect(@worker_base).to receive(:server_last_change).with(:last_config_change).thrice.and_return(1.minute.from_now.utc)
      expect(@worker_base.config_out_of_date?).to be_truthy
      expect(@worker_base.config_out_of_date?).to be_falsey
      expect(@worker_base.config_out_of_date?).to be_falsey
    end

    it "returns true when last config change was updated" do
      expect(@worker_base).to receive(:server_last_change).with(:last_config_change).twice.and_return(1.minute.ago.utc, 1.minute.from_now.utc)

      expect(@worker_base.config_out_of_date?).to be_falsey
      expect(@worker_base.config_out_of_date?).to be_truthy
    end
  end

  context "#initialize" do
    let(:worker) do
      server_id = EvmSpecHelper.local_miq_server.id
      FactoryBot.create(:miq_worker, :miq_server_id => server_id, :type => "MiqGenericWorker")
    end

    let!(:runner) { MiqWorker::Runner.new(:guid => worker.guid) }

    it "configures the #worker attribute correctly" do
      expect(runner.worker.id).to eq(worker.id)
      expect(runner.worker.guid).to eq(worker.guid)
    end

    it "sets the MiqWorker.my_guid class attribute" do
      expect(MiqWorker.my_guid).to eq(worker.guid)
    end
  end
end
