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

  context ".ruby_object_usage" do
    it "handles BasicObjects in memory" do
      10.times { BasicObject.new }
      usage = described_class.ruby_object_usage
      %w[String Array Class Regexp Hash].each do |klass|
        expect(usage[klass]).to be > 0
      end
    end
  end

  context "#initialize" do
    let(:worker) do
      server_id = EvmSpecHelper.local_miq_server.id
      FactoryBot.create(:miq_worker, :miq_server_id => server_id, :type => "MiqGenericWorker")
    end

    let!(:runner) { MiqGenericWorker::Runner.new(:guid => worker.guid) }

    it "configures the #worker attribute correctly" do
      expect(runner.worker.id).to eq(worker.id)
      expect(runner.worker.guid).to eq(worker.guid)
    end

    it "sets the MiqWorker.my_guid class attribute" do
      expect(MiqWorker.my_guid).to eq(worker.guid)
    end
  end

  context "#rails_worker? false" do
    let(:worker) do
      miq_server = EvmSpecHelper.local_miq_server
      FactoryBot.create(:miq_generic_worker, :miq_server_id => miq_server.id)
    end

    let!(:runner) { worker.class::Runner.new(:guid => worker.guid) }

    before { allow(worker).to receive(:rails_worker?).and_return(false) }

    describe "#worker_env (private)" do
      it "returns environment variables for the worker" do
        expect(runner.send(:worker_env)).to include(
          "APP_ROOT"              => Rails.root.to_s,
          "GUID"                  => worker.guid,
          "WORKER_HEARTBEAT_FILE" => worker.heartbeat_file
        )
      end
    end

    describe "#worker_options (private)" do
      it "returns messaging options" do
        expect(runner.send(:worker_options)).to include(:messaging => MiqQueue.messaging_client_options)
      end

      it "returns worker-specific worker settings" do
        expect(runner.send(:worker_options)).to include(
          :settings => hash_including(
            :worker_settings => hash_including(:count => 2)
          )
        )
      end

      it "returns default settings from the parent" do
        expect(runner.send(:worker_options)).to include(
          :settings => hash_including(
            :worker_settings => hash_including(:poll_method => "normal")
          )
        )
      end

      it "returns settings with integer values not strings like '10.minutes'" do
        expect(runner.send(:worker_options)).to include(
          :settings => hash_including(
            :worker_settings => hash_including(
              :memory_threshold => 1.gigabyte,
              :starting_timeout => 600
            )
          )
        )
      end

      it "returns additional settings requested by the worker class" do
        allow(worker.class).to receive(:worker_settings_paths).and_return([%i[log level]])
        expect(runner.send(:worker_options)).to include(
          :settings => hash_including(
            :log => hash_including(:level => "info")
          )
        )
      end

      it "returns settings with encrypted passwords decrypted" do
        stub_settings_merge(:http_proxy => {:default => {:password => ManageIQ::Password.encrypt("secret")}})
        allow(worker.class).to receive(:worker_settings_paths).and_return([%i[http_proxy default]])

        expect(runner.send(:worker_options)).to include(
          :settings => hash_including(
            :http_proxy => hash_including(
              :default => hash_including(
                :password => "secret"
              )
            )
          )
        )
      end
    end

    describe ".worker_cmdline (private)" do
      it "returns a path to the worker binary" do
        expect(runner.send(:worker_cmdline)).to eq(Rails.root.join("workers/miq_generic_worker/worker").to_s)
      end
    end
  end
end
