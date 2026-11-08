RSpec.describe TokenStore do
  describe ".acquire" do
    context "when session_store is 'cache'" do
      before { stub_settings(:server => {:session_store => "cache"}) }
      after  { described_class.token_caches.clear }

      it "returns an ActiveSupport::Cache::MemCacheStore" do
        stub_const("ENV", ENV.to_h.except("MEMCACHED_SERVER", "MEMCACHED_ENABLE_SSL"))
        stub_settings(:server  => {:session_store   => "cache"},
                      :session => {:memcache_server => "localhost:11211"})

        store = described_class.acquire("UI", 600)

        expect(store).to be_a(ActiveSupport::Cache::MemCacheStore)
      end

      it "memoizes the store for the same namespace" do
        stub_settings(:server  => {:session_store   => "cache"},
                      :session => {:memcache_server => "localhost:11211"})
        stub_const("ENV", ENV.to_h.except("MEMCACHED_SERVER", "MEMCACHED_ENABLE_SSL"))

        store1 = described_class.acquire("UI", 600)
        store2 = described_class.acquire("UI", 600)

        expect(store1).to be(store2)
      end

      it "returns different stores for different namespaces" do
        stub_settings(:server  => {:session_store   => "cache"},
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

    context "when session_store is sql" do
      before { stub_settings_merge(:server => {:session_store => "sql"}) }
      after  { described_class.token_caches.clear }

      it "returns a TokenStore::SqlStore that namespaces keys under MIQ:TOKENS:UI" do
        store = described_class.acquire("ui", 300)

        expect(store).to be_kind_of(TokenStore::SqlStore)
        store.write("tok1", {:userid => "alice", :expires_on => 1.hour.from_now})
        expect(Session.find_by(:session_id => "MIQ:TOKENS:UI:tok1")).to be_present
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

  describe TokenStore::KeyValueHelpers do
    let(:store) do
      ActiveSupport::Cache::MemoryStore.new.tap do |s|
        s.extend(described_class)
      end
    end

    describe "#create_user_token and #delete_all_for_user" do
      it "tracks tokens per user and deletes all tokens for that user" do
        token1 = "tok_1"
        token2 = "tok_2"
        data1  = {:userid => "alice", :role => "admin"}
        data2  = {:userid => "alice", :role => "user"}

        store.create_user_token(token1, data1, {})
        store.create_user_token(token2, data2, {})

        expect(store.read(token1)).to eq(data1)
        expect(store.read(token2)).to eq(data2)
        expect(store.read("tokens_for_alice")).to eq([token1, token2])

        store.delete_all_for_user("alice")

        expect(store.read(token1)).to be_nil
        expect(store.read(token2)).to be_nil
        expect(store.read("tokens_for_alice")).to be_nil
      end
    end
  end
end
