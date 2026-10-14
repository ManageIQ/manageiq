RSpec.describe TokenStore do
  before { TokenStore.token_caches.clear }
  after  { TokenStore.token_caches.clear }

  describe ".acquire" do
    context "when session_store is cache" do
      before do
        stub_settings_merge(
          :server  => {:session_store => "cache"},
          :session => {:memcache_server => "127.0.0.1:11211"}
        )
      end

      it "returns an ActiveSupport::Cache::MemCacheStore with KeyValueHelpers and correct options" do
        store = described_class.acquire("api", 300)

        expect(store).to be_kind_of(ActiveSupport::Cache::MemCacheStore)
        expect(store).to be_kind_of(described_class::KeyValueHelpers)
        expect(store.options[:namespace]).to eq("MIQ:TOKENS:API")
        expect(store.options[:expires_in]).to eq(300)
        expect(store.options[:pool]).to eq(:size => 10)
      end

      it "caches acquired stores by namespace" do
        store1 = described_class.acquire("api", 300)
        store2 = described_class.acquire("api", 300)

        expect(store1).to be(store2)
      end
    end

    context "when session_store is memory" do
      before { stub_settings_merge(:server => {:session_store => "memory"}) }

      it "returns an ActiveSupport::Cache::MemoryStore with KeyValueHelpers" do
        store = described_class.acquire("ws", 600)

        expect(store).to be_kind_of(ActiveSupport::Cache::MemoryStore)
        expect(store).to be_kind_of(described_class::KeyValueHelpers)
      end
    end

    context "when session_store is sql" do
      before { stub_settings_merge(:server => {:session_store => "sql"}) }

      it "returns a TokenStore::SqlStore" do
        store = described_class.acquire("ui", 300)

        expect(store).to be_kind_of(TokenStore::SqlStore)
      end
    end

    context "when session_store is unsupported" do
      before { stub_settings_merge(:server => {:session_store => "invalid_store"}) }

      it "raises an error" do
        expect { described_class.acquire("api", 300) }.to raise_error(/unsupported session store type/)
      end
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
