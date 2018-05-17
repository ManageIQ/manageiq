describe VMDB::Config do
  let(:password) { "pa$$w0rd" }
  let(:enc_pass) { MiqPassword.encrypt(password) }

  describe ".get_file" do
    it "for current server" do
      _guid, server, _zone = EvmSpecHelper.local_guid_miq_server_zone
      Vmdb::Settings.save!(
        server,
        :http_proxy => {
          :default => {
            :host     => "proxy.example.com",
            :user     => "user",
            :password => password,
            :port     => 80
          }
        }
      )
      server.reload
      yaml = VMDB::Config.get_file
      yaml = YAML.load(yaml)
      expect(yaml.fetch_path(:http_proxy, :default, :host)).to eq "proxy.example.com"
      expect(yaml.fetch_path(:http_proxy, :default, :user)).to eq "user"
      expect(yaml.fetch_path(:http_proxy, :default, :port)).to eq 80
      expect(yaml.fetch_path(:http_proxy, :default, :password)).to be_encrypted
    end

    it "for specified resource" do
      resource = FactoryGirl.create(:miq_server)
      Vmdb::Settings.save!(
        resource,
        :http_proxy => {
          :default => {
            :host     => "proxy.example.com",
            :user     => "user",
            :password => password,
            :port     => 80
          }
        }
      )
      resource.reload
      yaml = VMDB::Config.get_file(resource)
      yaml = YAML.load(yaml)
      expect(yaml.fetch_path(:http_proxy, :default, :host)).to eq "proxy.example.com"
      expect(yaml.fetch_path(:http_proxy, :default, :user)).to eq "user"
      expect(yaml.fetch_path(:http_proxy, :default, :port)).to eq 80
      expect(yaml.fetch_path(:http_proxy, :default, :password)).to be_encrypted
    end
  end

  context ".save_file" do
    it "normal" do
      resource = FactoryGirl.create(:miq_server)
      MiqRegion.seed
      data = {}
      data.store_path(:api, :token_ttl, "1.day")
      data = data.to_yaml

      expect(VMDB::Config.save_file(data, resource)).to be true
      expect(SettingsChange.count).to eq(1)
      expect(SettingsChange.first).to have_attributes(:key => '/api/token_ttl', :value => "1.day")
    end

    it "catches syntax errors" do
      errors = VMDB::Config.save_file("xxx")
      expect(errors.length).to eq(1)
      expect(errors.first[0]).to eq(:contents)
      expect(errors.first[1]).to start_with("File contents are malformed")
    end
  end

  it "#save" do
    server = FactoryGirl.create(:miq_server)
    MiqRegion.seed

    config = server.get_config
    config.config.store_path(:api, :token_ttl, "1.day")
    config.save(server)

    expect(SettingsChange.count).to eq(1)
    expect(SettingsChange.first).to have_attributes(:key => '/api/token_ttl', :value => "1.day")
  end

  it "#set_worker_setting!" do
    EvmSpecHelper.local_miq_server

    config = VMDB::Config.new("vmdb")
    config.set_worker_setting!(:MiqEmsMetricsCollectorWorker, :memory_threshold, "1.terabyte")

    fq_keys = [:workers, :worker_base, :queue_worker_base, :ems_metrics_collector_worker, :memory_threshold]
    v = config.config.fetch_path(fq_keys).to_i_with_method
    expect(v).to eq(1.terabyte)
  end
end
