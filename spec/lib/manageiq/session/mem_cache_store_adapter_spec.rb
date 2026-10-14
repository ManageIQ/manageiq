describe ManageIQ::Session::MemCacheStoreAdapter do
  let(:adapter) { described_class.new }

  describe "#type" do
    it "returns :mem_cache_store" do
      expect(adapter.type).to eq(:mem_cache_store)
    end
  end

  describe "#session_options" do
    it "merges default client options with mem_cache_store session options" do
      stub_settings_merge(:session => {:memcache_server => "127.0.0.1:11211"})

      options = adapter.session_options

      expect(options[:expire_after]).to eq(24.hours)
      expect(options[:key]).to eq("_vmdb_session")
      expect(options[:memcache_server]).to eq("127.0.0.1:11211")
      expect(options[:namespace]).to eq("MIQ:VMDB")
      expect(options[:pool_size]).to eq(10)
      expect(options[:value_max_bytes]).to eq(10.megabytes)
      expect(options[:socket_max_failures]).to eq(5)
      expect(options[:threadsafe]).to be(true)
    end
  end

  describe "#rack_session_class_to_prepend" do
    it "returns ::Rack::Session::Dalli" do
      expect(adapter.rack_session_class_to_prepend).to eq(Rack::Session::Dalli)
    end
  end

  describe "Rack::Session::Dalli compatibility" do
    it "initializes Rack::Session::Dalli with adapter session_options" do
      stub_settings_merge(:session => {:memcache_server => "127.0.0.1:11211"})
      app = ->(_env) { [200, {}, ["OK"]] }

      session_class = adapter.rack_session_class_to_prepend
      session_middleware = session_class.new(app, adapter.session_options)

      expect(session_middleware).to be_kind_of(session_class)

      # Rack session options are stored in default_options by the parent class
      expect(session_middleware.default_options[:expire_after]).to eq(24.hours)
      expect(session_middleware.default_options[:namespace]).to eq("MIQ:VMDB")

      # pool_size is consumed to build a ConnectionPool; verify size was accepted
      expect(session_middleware.data).to be_kind_of(ConnectionPool)
      expect(session_middleware.data.size).to eq(10)
    end
  end

  describe "#enable_rack_session_debug_logger" do
    it "returns nil in production environment" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      expect(adapter).to receive(:rack_session_class_to_prepend).never
      expect(adapter.enable_rack_session_debug_logger).to be_nil
    end

    context "in non-production environment" do
      let(:mock_class) { Class.new }

      it "enables debug logging and returns a truthy value" do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
        allow(adapter).to receive(:rack_session_class_to_prepend).and_return(mock_class)

        expect(mock_class).to receive(:prepend).and_call_original
        expect(adapter).to receive(:puts).with(/enabling/i)
        expect(adapter.enable_rack_session_debug_logger).to be_truthy
      end
    end
  end
end
