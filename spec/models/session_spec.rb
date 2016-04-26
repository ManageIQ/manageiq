describe Session do
  describe ".purge" do
    it "purges an old session" do
      FactoryGirl.create(:session, :updated_at => 1.year.ago, :data => Base64.encode64(Marshal.dump(:userid=>"admin")))

      expect(described_class.count).to eq(1)

      described_class.purge(1)

      expect(described_class.count).to be_zero
    end

    it "purges in batches" do
      2.times do
        FactoryGirl.create(:session, :updated_at => 1.year.ago, :data => Base64.encode64(Marshal.dump(:userid=>"admin")))
      end

      expect(described_class.count).to eq(2)

      described_class.purge(1)

      expect(described_class.count).to be_zero
      expect(described_class).to receive(:delete_batched).exactly(2).times
    end
  end
end