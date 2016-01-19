describe VMDB::Config do
  let(:password) { "password" }
  let(:enc_pass) { MiqPassword.encrypt(password) }

  it ".load_config_file" do
    allow(IO).to receive_messages(:read => "---\r\nsmtp:\r\n  password: #{enc_pass}\r\n")
    allow(File).to receive(:exist?).with("test.yml").and_return(true)
    expect(described_class.load_config_file("test.yml")).to eq({:smtp => {:password => password}})
  end

  context "#config_mtime_from_db" do
    let(:config) { described_class.new("vmdb") }

    it "nil server" do
      expect(config.config_mtime_from_db).to eq(Time.at(0))
    end

    it "server with configuration changes" do
      _guid, server, _zone = EvmSpecHelper.create_guid_miq_server_zone
      server.configurations << Configuration.create(:typ => "vmdb")
      db_record = server.reload.configurations.first
      time = config.config_mtime_from_db
      expect(time).to be_utc
      expect(time).to be_within(1.second).of(db_record.updated_on)
    end

    it "server without configuration changes" do
      _guid, _server, _zone = EvmSpecHelper.create_guid_miq_server_zone
      # Note: server.configurations is empty
      expect(config.config_mtime_from_db).to eq(Time.at(0))
    end
  end

  it ".get_file" do
    server        = EvmSpecHelper.create_guid_miq_server_zone[1]
    config        = VMDB::Config.new("vmdb")
    config.config = {:log_depot => {:uri => "smb://server/share", :username => "user", :password => password}}
    config.save

    expect(VMDB::Config.get_file("vmdb")).to eq(
      "---\nlog_depot:\n  uri: smb://server/share\n  username: user\n  password: #{enc_pass}\n"
    )
  end

  context "#save" do
    it "to the database" do
      EvmSpecHelper.create_guid_miq_server_zone
      config = VMDB::Config.new("vmdb")
      config.config = {:one => {:two => :three}}
      expect(config).to receive(:save_file)
      config.save
      expect(Configuration.count).to eq(1)
      expect(Configuration.first).to have_attributes(:typ => 'vmdb', :settings => {:one => {:two => :three}})
    end
  end

  context "load_and_validate_raw_contents" do
    it "normal" do
      validated, result = VMDB::Config.load_and_validate_raw_contents("vmdb", "---\n'a':\n  'b': 1\n")
      expect(validated).to eql(true)
      expect(result).to be_kind_of(VMDB::Config)
    end

    it "catches syntax errors" do
      validated, result = VMDB::Config.load_and_validate_raw_contents("vmdb", "---\n'a':\n  'b':1\n")
      expect(validated).to eql(false)
      error = result.first
      expect(error[0]).to eql(:contents)
      expect(error[1]).to match(/\AFile contents are malformed/)
    end
  end

  describe "set_worker_setting!" do
    it "stores path" do
      config = VMDB::Config.new("vmdb")
      config.set_worker_setting!(:MiqEmsMetricsCollectorWorker, :memory_threshold, "250.megabytes")

      fq_keys = [:workers, :worker_base, :queue_worker_base, :ems_metrics_collector_worker] + [:memory_threshold]
      v = config.config.fetch_path(fq_keys).to_i_with_method
      expect(v).to eq(250.megabytes)
    end
  end
end
