RSpec.describe TokenManager do
  describe "#token_ttl" do
    it "returns the ttl" do
      token_manager = described_class.new(described_class::DEFAULT_NS, :token_ttl => 60)

      expect(token_manager.token_ttl).to eq(60)
    end

    it "defaults to 10 minutes" do
      token_manager = described_class.new

      expect(token_manager.token_ttl).to eq(600)
    end
  end
end
