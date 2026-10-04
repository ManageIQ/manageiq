describe ManageIQ::Session::MemCacheStoreAdapter do
  let(:adapter) { described_class.new }

  describe "#type" do
    it "returns :mem_cache_store" do
      expect(adapter.type).to eq(:mem_cache_store)
    end
  end

  describe "#session_options" do
    before do
      stub_const("ENV", ENV.to_h.except("MEMCACHED_SERVER", "MEMCACHED_ENABLE_SSL"))
      stub_settings(:session => {:memcache_server => "localhost:11211"})
      allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
    end

    it "returns the expected options" do
      options = adapter.session_options

      expect(options[:expire_after]).to eq(24.hours)
      expect(options[:key]).to eq("_vmdb_session")
      expect(options[:memcache_server]).to eq("localhost:11211")
      expect(options[:namespace]).to eq("MIQ:VMDB")
      expect(options[:pool_size]).to eq(10)
      expect(options[:socket_max_failures]).to eq(5)
      expect(options[:threadsafe]).to be(true)
      expect(options[:value_max_bytes]).to eq(10.megabytes)
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
