RSpec.describe MiqMemcached do
  describe ".server_address" do
    it "defaults to Settings.session.memcache_server" do
      stub_settings_merge(:session => {:memcache_server => "127.0.0.1:11211"})
      expect(described_class.server_address).to eq("127.0.0.1:11211")
    end

    it "prefers MEMCACHED_SERVER environment variable" do
      stub_settings_merge(:session => {:memcache_server => "127.0.0.1:11211"})
      stub_const("ENV", ENV.to_h.merge("MEMCACHED_SERVER" => "memcache.example.com:11211"))
      expect(described_class.server_address).to eq("memcache.example.com:11211")
    end
  end

  describe ".default_client_options" do
    it "includes non-default socket and threadsafe options" do
      options = described_class.default_client_options

      expect(options[:socket_max_failures]).to eq(5)
      expect(options[:threadsafe]).to be(true)
      expect(options[:ssl_context]).to be_nil
    end

    context "when MEMCACHED_ENABLE_SSL is set" do
      it "configures SSL context with hostname verification and peer verification" do
        stub_const("ENV", ENV.to_h.merge("MEMCACHED_ENABLE_SSL" => "true"))

        options = described_class.default_client_options
        ssl_context = options[:ssl_context]

        expect(ssl_context).to be_kind_of(OpenSSL::SSL::SSLContext)
        expect(ssl_context.verify_hostname).to be(true)
        expect(ssl_context.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
      end

      it "sets ca_file when MEMCACHED_SSL_CA is present" do
        stub_const("ENV", ENV.to_h.merge("MEMCACHED_ENABLE_SSL" => "true", "MEMCACHED_SSL_CA" => "/path/to/ca.crt"))

        options = described_class.default_client_options
        expect(options[:ssl_context].ca_file).to eq("/path/to/ca.crt")
      end
    end
  end

  describe ".client" do
    it "passes the configured server and merged options to Dalli::Client" do
      require 'dalli'
      stub_settings_merge(:session => {:memcache_server => "127.0.0.1:11211"})

      expect(Dalli::Client).to receive(:new).with(
        "127.0.0.1:11211",
        hash_including(
          :socket_max_failures => 5,
          :threadsafe          => true,
          :namespace           => "server_monitor"
        )
      ).and_call_original

      client = described_class.client(:namespace => "server_monitor")

      expect(client).to be_kind_of(Dalli::Client)
    end
  end

  describe ".verify_version" do
    let(:client) { instance_double(Dalli::Client, :close => nil) }

    before do
      require 'dalli'
      stub_const("Dalli::MIN_SUPPORTED_MEMCACHED_VERSION", "1.6.27")
      allow(described_class).to receive(:client).and_return(client)
    end

    it "returns true and does not warn when the server meets the minimum" do
      allow(client).to receive(:version).and_return("localhost:11211" => "1.6.27")
      expect($log).not_to receive(:warn)

      expect(described_class.verify_version).to be(true)
    end

    it "returns true when the server is newer than the minimum" do
      allow(client).to receive(:version).and_return("localhost:11211" => "1.6.41")
      expect($log).not_to receive(:warn)

      expect(described_class.verify_version).to be(true)
    end

    it "warns and returns false when the server is older than the minimum" do
      allow(client).to receive(:version).and_return("localhost:11211" => "1.6.9")
      expect($log).to receive(:warn).with(/localhost:11211 is version 1\.6\.9, but Dalli .* requires 1\.6\.27 or later/)

      expect(described_class.verify_version).to be(false)
    end

    it "warns for every server that is too old" do
      allow(client).to receive(:version).and_return("a:11211" => "1.6.9", "b:11211" => "1.6.23", "c:11211" => "1.6.30")
      expect($log).to receive(:warn).twice

      expect(described_class.verify_version).to be(false)
    end

    it "ignores servers that cannot be reached" do
      allow(client).to receive(:version).and_return("localhost:11211" => nil)
      expect($log).not_to receive(:warn)

      expect(described_class.verify_version).to be(true)
    end

    it "warns and does not raise when the version check fails" do
      allow(client).to receive(:version).and_raise(Dalli::DalliError, "boom")
      expect($log).to receive(:warn).with(/Unable to verify memcached version: Dalli::DalliError: boom/)

      expect(described_class.verify_version).to be(true)
    end

    it "closes the client" do
      allow(client).to receive(:version).and_return("localhost:11211" => "1.6.27")
      expect(client).to receive(:close)

      described_class.verify_version
    end
  end
end
