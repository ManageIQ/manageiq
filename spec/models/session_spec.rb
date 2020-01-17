RSpec.describe Session do
  describe "#raw_data" do
    it "returns the unmarshaled data" do
      session = FactoryBot.build(:session, :data => "BAh7BjoLdXNlcmlkSSIKYWRtaW4GOgZFVA==\n")

      expect(session.raw_data).to eq(:userid => "admin")
    end

    it "can handle newlines" do
      session = FactoryBot.build(
        :session,
        :data => "BAh7CDoIZm9vSSIIYmFyBjoGRVQ6CGJhekkiCHF1eAY7BlQ6CXF1dXhJIglx\ndXV6BjsGVA==\n"
      )

      expect(session.raw_data).to eq(:foo => "bar", :baz => "qux", :quux => "quuz")
    end
  end

  describe "#raw_data=" do
    it "marshals the data" do
      session = FactoryBot.build(:session, :raw_data => {:userid => "admin"})

      expect(session.data).to eq("BAh7BjoLdXNlcmlkSSIKYWRtaW4GOgZFVA==\n")
    end
  end

  describe ".purge" do
    it "purges an old session" do
      FactoryBot.create(:session, :updated_at => 1.year.ago, :raw_data => {:userid => "admin"})

      expect { described_class.purge(0, 1) }.to(change { described_class.count }.from(1).to(0))
    end

    it "logs out users before destroying stale sessions" do
      FactoryBot.create(:session, :updated_at => 1.year.ago, :raw_data => {:userid => "admin"})
      user = instance_double(User, :lastlogoff => 2.days.ago, :lastlogon => 1.day.ago)
      allow(User).to receive(:where).with(:userid => ["admin"]).and_return([user])

      expect(user).to receive(:logoff)

      described_class.purge(0)
    end

    it "handles a session with bad data" do
      FactoryBot.create(:session, :updated_at => 1.year.ago, :data => "Data that can't be marshaled")

      expect { described_class.purge(0) }.to(change { described_class.count }.from(1).to(0))
    end

    context "given some token store data" do
      around { |example| Timecop.freeze { example.run } }

      it "will purge an expired token" do
        FactoryBot.create(:session, :raw_data => {:expires_on => 1.second.ago})

        expect { described_class.purge(0) }.to(change { described_class.count }.from(1).to(0))
      end

      it "won't purge an unexpired token" do
        FactoryBot.create(:session, :raw_data => {:expires_on => 1.second.from_now})

        expect { described_class.purge(0) }.not_to(change { described_class.count })
      end
    end

    describe ".purge_one_batch" do
      it "purges one batch" do
        FactoryBot.create_list(:session, 2, :updated_at => 1.year.ago, :raw_data => {:userid => "admin"})

        expect do
          expect(described_class.purge_one_batch(0, 1)).to eq 1
        end.to(change { described_class.count }.from(2).to(1))
      end
    end
  end
end
