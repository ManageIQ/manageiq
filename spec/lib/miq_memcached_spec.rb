RSpec.describe MiqMemcached do
  describe ".server_address" do
    it "prefers the MEMCACHED_SERVER env var" do
      stub_const("ENV", ENV.to_h.merge("MEMCACHED_SERVER" => "envhost:11211"))
      stub_settings(:session => {:memcache_server => "settingshost:11211"})

      expect(described_class.server_address).to eq("envhost:11211")
    end

    it "falls back to Settings when env var is absent" do
      stub_const("ENV", ENV.to_h.except("MEMCACHED_SERVER"))
      stub_settings(:session => {:memcache_server => "settingshost:11211"})

      expect(described_class.server_address).to eq("settingshost:11211")
    end
  end

  describe ".default_client_options" do
    context "without SSL" do
      before { stub_const("ENV", ENV.to_h.except("MEMCACHED_ENABLE_SSL")) }

      it "includes socket_max_failures, threadsafe, and silence_marshal_warning" do
        options = described_class.default_client_options

        expect(options[:socket_max_failures]).to eq(5)
        expect(options[:threadsafe]).to be(true)
        expect(options[:silence_marshal_warning]).to be(true)
      end

      it "does not include ssl_context" do
        expect(described_class.default_client_options).not_to have_key(:ssl_context)
      end
    end

    context "with SSL enabled" do
      before do
        stub_const("ENV", ENV.to_h.merge("MEMCACHED_ENABLE_SSL" => "true").except("MEMCACHED_SSL_CA"))
      end

      it "includes an ssl_context" do
        options = described_class.default_client_options

        expect(options[:ssl_context]).to be_a(OpenSSL::SSL::SSLContext)
      end

      it "configures VERIFY_PEER and verify_hostname on the ssl_context" do
        ssl_context = described_class.default_client_options[:ssl_context]

        expect(ssl_context.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(ssl_context.verify_hostname).to be(true)
      end

      context "when MEMCACHED_SSL_CA is set" do
        let(:ca_file) { Rails.root.join("tmp", "test_ca.pem").to_s }

        before do
          stub_const("ENV", ENV.to_h.merge("MEMCACHED_ENABLE_SSL" => "true", "MEMCACHED_SSL_CA" => ca_file))
          FileUtils.touch(ca_file)
        end

        after { FileUtils.rm_f(ca_file) }

        it "sets ca_file on the ssl_context" do
          expect(described_class.default_client_options[:ssl_context].ca_file).to eq(ca_file)
        end
      end
    end
  end

  describe ".client" do
    before do
      stub_const("ENV", ENV.to_h.except("MEMCACHED_SERVER", "MEMCACHED_ENABLE_SSL"))
      stub_settings(:session => {:memcache_server => "localhost:11211"})
    end

    it "returns a Dalli::Client" do
      expect(described_class.client(:namespace => "test_ns")).to be_a(Dalli::Client)
    end

    it "merges default options into the client" do
      client = described_class.client(:namespace => "test_ns")
      options = client.instance_variable_get(:@options)

      expect(options[:socket_max_failures]).to eq(5)
      expect(options[:threadsafe]).to be(true)
    end

    it "passes caller-supplied options through to the client" do
      client = described_class.client(:namespace => "test_ns")
      options = client.instance_variable_get(:@options)

      expect(options[:namespace]).to eq("test_ns")
    end

    it "caller options override defaults" do
      client = described_class.client(:namespace => "test_ns", :socket_max_failures => 99)
      options = client.instance_variable_get(:@options)

      expect(options[:socket_max_failures]).to eq(99)
    end
  end
end
