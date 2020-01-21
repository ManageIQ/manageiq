RSpec.describe TokenStore::SqlStore do
  around { |example| Timecop.freeze { example.run } }

  describe "#write" do
    it "creates a session" do
      store = build_sql_store
      token = SecureRandom.hex
      data = {
        :expires_on => 1.hour.from_now,
        :token_ttl  => 1.hour,
        :userid     => "alice"
      }

      expect { store.write(token, data) }.to change(Session, :count).by(1)
    end

    it "updates a session if it exists" do
      store = build_sql_store("TEST")
      token = SecureRandom.hex
      session = FactoryBot.create(
        :session,
        :session_id => "TEST:#{token}",
        :raw_data   => {:expires_on => 1.second.from_now}
      )

      store.write(token, :expires_on => 1.hour.from_now)

      expect(session.reload.raw_data[:expires_on]).to eq(1.hour.from_now)
    end
  end

  describe "#read" do
    it "reads a valid token" do
      store = build_sql_store("TEST")
      token = SecureRandom.hex
      FactoryBot.create(
        :session,
        :session_id => "TEST:#{token}",
        :raw_data   => {:userid => "alice", :expires_on => 1.second.from_now}
      )

      data = store.read(token)

      expect(data[:userid]).to eq("alice")
    end

    it "returns nil for an expired token" do
      store = build_sql_store("TEST")
      token = SecureRandom.hex
      FactoryBot.create(
        :session,
        :session_id => "TEST:#{token}",
        :raw_data   => {:userid => "alice", :expires_on => 1.second.ago}
      )

      data = store.read(token)

      expect(data).to be_nil
    end

    it "returns nil if no token can be found" do
      store = build_sql_store("TEST")
      token = SecureRandom.hex

      data = store.read(token)

      expect(data).to be_nil
    end
  end

  describe "#delete" do
    it "deletes a token" do
      store = build_sql_store("TEST")
      token = SecureRandom.hex
      FactoryBot.create(
        :session,
        :session_id => "TEST:#{token}",
        :raw_data   => {:userid => "alice", :expires_on => 1.hour.from_now}
      )

      expect { store.delete(token) }.to change(Session, :count).by(-1)
    end
  end

  def build_sql_store(namespace = "FOO")
    described_class.new(:namespace => namespace)
  end
end
