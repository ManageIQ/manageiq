RSpec.describe TokenStore do
  describe ".acquire" do
    context "when session_store is 'cache'" do
      before { stub_settings(:server => {:session_store => "cache"}) }
      after  { described_class.token_caches.clear }

      it "returns an ActiveSupport::Cache::MemCacheStore" do
        stub_const("ENV", ENV.to_h.except("MEMCACHED_SERVER", "MEMCACHED_ENABLE_SSL"))
        stub_settings(:server  => {:session_store  => "cache"},
                      :session => {:memcache_server => "localhost:11211"})

        store = described_class.acquire("UI", 600)

        expect(store).to be_a(ActiveSupport::Cache::MemCacheStore)
      end

      it "memoizes the store for the same namespace" do
        stub_settings(:server  => {:session_store  => "cache"},
                      :session => {:memcache_server => "localhost:11211"})
        stub_const("ENV", ENV.to_h.except("MEMCACHED_SERVER", "MEMCACHED_ENABLE_SSL"))

        store1 = described_class.acquire("UI", 600)
        store2 = described_class.acquire("UI", 600)

        expect(store1).to be(store2)
      end

      it "returns different stores for different namespaces" do
        stub_settings(:server  => {:session_store  => "cache"},
                      :session => {:memcache_server => "localhost:11211"})
        stub_const("ENV", ENV.to_h.except("MEMCACHED_SERVER", "MEMCACHED_ENABLE_SSL"))

        ui_store    = described_class.acquire("UI", 600)
        token_store = described_class.acquire("API", 600)

        expect(ui_store).not_to be(token_store)
      end
    end

    context "when session_store is 'memory'" do
      before { stub_settings(:server => {:session_store => "memory"}) }
      after  { described_class.token_caches.clear }

      it "returns an ActiveSupport::Cache::MemoryStore" do
        store = described_class.acquire("UI", 600)

        expect(store).to be_a(ActiveSupport::Cache::MemoryStore)
      end
    end

    context "when session_store is unsupported" do
      before { stub_settings(:server => {:session_store => "redis"}) }
      after  { described_class.token_caches.clear }

      it "raises an error" do
        expect { described_class.acquire("UI", 600) }.to raise_error(RuntimeError, /unsupported session store type/)
      end
    end
  end

  describe ".cache_store_options (private)" do
    it "includes the namespace scoped with MIQ:TOKENS" do
      stub_const("ENV", ENV.to_h.except("MEMCACHED_ENABLE_SSL"))

      options = described_class.send(:cache_store_options, "UI", 600)

      expect(options[:namespace]).to eq("MIQ:TOKENS:UI")
    end

    it "upcases the namespace" do
      stub_const("ENV", ENV.to_h.except("MEMCACHED_ENABLE_SSL"))

      options = described_class.send(:cache_store_options, "ui", 600)

      expect(options[:namespace]).to eq("MIQ:TOKENS:UI")
    end

    it "sets expires_in to the given ttl" do
      stub_const("ENV", ENV.to_h.except("MEMCACHED_ENABLE_SSL"))

      options = described_class.send(:cache_store_options, "UI", 600)

      expect(options[:expires_in]).to eq(600)
    end

    it "includes a pool hash with size: 10" do
      stub_const("ENV", ENV.to_h.except("MEMCACHED_ENABLE_SSL"))

      options = described_class.send(:cache_store_options, "UI", 600)

      expect(options[:pool]).to include(:size => 10)
    end

    it "merges MiqMemcached default_client_options" do
      stub_const("ENV", ENV.to_h.except("MEMCACHED_ENABLE_SSL"))

      options = described_class.send(:cache_store_options, "UI", 600)

      expect(options[:socket_max_failures]).to eq(5)
      expect(options[:threadsafe]).to be(true)
    end
  end
end
