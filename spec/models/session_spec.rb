describe Session do
  describe "#raw_data" do
    it "returns the unmarshaled data" do
      session = FactoryGirl.build(:session, :data => "BAh7BjoLdXNlcmlkSSIKYWRtaW4GOgZFVA==\n")

      expect(session.raw_data).to eq(:userid => "admin")
    end

    it "can handle newlines" do
      session = FactoryGirl.build(
        :session,
        :data => "BAh7CDoIZm9vSSIIYmFyBjoGRVQ6CGJhekkiCHF1eAY7BlQ6CXF1dXhJIglx\ndXV6BjsGVA==\n"
      )

      expect(session.raw_data).to eq(:foo => "bar", :baz => "qux", :quux => "quuz")
    end
  end

  describe "#raw_data=" do
    it "marshals the data" do
      session = FactoryGirl.build(:session, :raw_data => {:userid => "admin"})

      expect(session.data).to eq("BAh7BjoLdXNlcmlkSSIKYWRtaW4GOgZFVA==\n")
    end
  end

  describe ".purge" do
    before do
      2.times do
        FactoryGirl.create(:session,
                           :updated_at => 1.year.ago,
                           :data       => Base64.encode64(Marshal.dump(:userid=>"admin"))
                          )
      end
    end

    it "purges an old session" do
      expect(described_class.count).to eq(2)

      described_class.purge(0, 1)

      expect(described_class.count).to be_zero
    end

    it "purges one batch" do
      expect(described_class.count).to eq(2)

      expect(described_class.purge_one_batch(0, 1)).to eq 1

      expect(described_class.count).to eq 1
    end

    it "logs out users before destroying stale sessions" do
      expect(described_class.count).to eq(2)
      expect(User).to receive(:where).and_return([User.new]).exactly(1).times

      described_class.purge(0)

      expect(described_class.count).to eq 0
    end

    it "handles a session with bad data" do
      FactoryGirl.create(:session,
                         :updated_at => 1.year.ago,
                         :data       => "Data that can't be marshaled"
                        )

      described_class.purge(0)

      expect(described_class.count).to eq 0
    end

    context "given some token store data" do
      around { |example| Timecop.freeze { example.run } }

      it "will purge an expired token" do
        FactoryGirl.create(
          :session,
          :data => serialize_data(
            :expires_on => 1.second.ago,
          )
        )

        described_class.purge(0)

        expect(described_class.count).to eq(0)
      end

      it "won't purge an unexpired token" do
        FactoryGirl.create(
          :session,
          :data => serialize_data(
            :expires_on => 1.second.from_now,
          )
        )

        described_class.purge(0)

        expect(described_class.count).to eq(1)
      end

      def serialize_data(data)
        Base64.encode64(Marshal.dump(data))
      end
    end
  end
end
