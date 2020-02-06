RSpec.describe SettingsChange do
  describe "#key_path" do
    it "with multiple parts in the key" do
      change = described_class.new(:key => "/api/token_ttl")
      expect(change.key_path).to eq %i(api token_ttl)
    end

    it "with one part in the key" do
      change = described_class.new(:key => "/api")
      expect(change.key_path).to eq %i(api)
    end

    it "with key of /" do
      change = described_class.new(:key => "/")
      expect(change.key_path).to be_empty
    end

    it "with blank key" do
      change = described_class.new(:key => "")
      expect(change.key_path).to be_empty
    end

    it "with nil key" do
      change = described_class.new(:key => nil)
      expect(change.key_path).to be_empty
    end
  end
end
