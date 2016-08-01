describe Session do
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
  end
end
