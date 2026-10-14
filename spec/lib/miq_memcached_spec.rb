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
end
