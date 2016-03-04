describe "Server Environment Management" do
  context ".spartan_mode" do
    before(:each) { MiqServer.class_eval { instance_variable_set :@spartan_mode, nil } }
    after(:each) { MiqServer.class_eval { instance_variable_set :@spartan_mode, nil } }

    it "when ENV['MIQ_SPARTAN'] is not set" do
      allow(ENV).to receive(:[]).with('MIQ_SPARTAN').and_return(nil)
      expect(MiqServer.spartan_mode).to be_blank
    end

    it "when ENV['MIQ_SPARTAN'] is set" do
      spartan = "minimal:foo:bar"
      allow(ENV).to receive(:[]).with('MIQ_SPARTAN').and_return(spartan)
      expect(MiqServer.spartan_mode).to eq(spartan)
    end
  end

  context ".minimal_env?" do
    it "when spartan_mode is 'minimal'" do
      allow(MiqServer).to receive(:spartan_mode).and_return("minimal")
      expect(MiqServer.minimal_env?).to be_truthy
    end

    it "when spartan_mode starts with 'minimal'" do
      allow(MiqServer).to receive(:spartan_mode).and_return("minimal:foo:bar")
      expect(MiqServer.minimal_env?).to be_truthy
    end

    it "when spartan_mode does not start with 'minimal'" do
      allow(MiqServer).to receive(:spartan_mode).and_return("foo:bar")
      expect(MiqServer.minimal_env?).to be_falsey
    end
  end

  context ".normal_env?" do
    it "when minimal_env? is true" do
      allow(MiqServer).to receive(:minimal_env?).and_return(true)
      expect(MiqServer.normal_env?).to be_falsey
    end

    it "when minimal_env? is false" do
      allow(MiqServer).to receive(:minimal_env?).and_return(false)
      expect(MiqServer.normal_env?).to be_truthy
    end
  end

  context ".minimal_env_options" do
    before(:each) { MiqServer.class_eval { instance_variable_set :@minimal_env_options, nil } }
    after(:each) { MiqServer.class_eval { instance_variable_set :@minimal_env_options, nil } }

    it "when spartan_mode is 'minimal'" do
      allow(MiqServer).to receive(:spartan_mode).and_return("minimal")
      expect(MiqServer.minimal_env_options).to eq([])
    end

    it "when spartan_mode starts with 'minimal' and has various roles" do
      allow(MiqServer).to receive(:spartan_mode).and_return("minimal:foo:bar")
      expect(MiqServer.minimal_env_options).to eq(%w(foo bar))
    end

    it "when spartan_mode does not start with 'minimal'" do
      allow(MiqServer).to receive(:spartan_mode).and_return("foo:bar")
      expect(MiqServer.minimal_env_options).to eq([])
    end
  end

  context ".startup_mode" do
    context "when minimal_env? is true" do
      before(:each) { allow(MiqServer).to receive(:minimal_env?).and_return(true) }

      it "when minimal_env_options is empty" do
        allow(MiqServer).to receive(:minimal_env_options).and_return([])
        expect(MiqServer.startup_mode).to eq("Minimal")
      end

      it "when minimal_env_options is not empty" do
        minimal_env_options = %w(foo bar)
        allow(MiqServer).to receive(:minimal_env_options).and_return(minimal_env_options)
        expect(MiqServer.startup_mode).to eq("Minimal [#{minimal_env_options.join(', ')}]")
      end
    end

    it "when minimal_env? is false" do
      allow(MiqServer).to receive(:minimal_env?).and_return(false)
      expect(MiqServer.startup_mode).to eq("Normal")
    end
  end

  context "#check_disk_usage" do
    before do
      _, @miq_server, = EvmSpecHelper.create_guid_miq_server_zone
      allow(@miq_server).to receive_messages(:disk_usage_threshold => 70)
    end

    it "normal usage" do
      expect(@miq_server.check_disk_usage([:used_bytes_percent => 50]))
      expect(MiqQueue.count).to eql 0
    end

    it "database disk exceeds usage" do
      disks = [{:used_bytes_percent => 85, :mount_point => '/var/lib/pgsql/data'}]
      expect(@miq_server.check_disk_usage(disks))
      queue = MiqQueue.first

      expect(queue.args[1]).to eql 'evm_server_db_disk_high_usage'
      expect(queue.args[2][:event_details]).to include disks.first[:mount_point]
    end
  end
end
