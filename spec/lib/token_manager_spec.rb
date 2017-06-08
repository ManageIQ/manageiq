RSpec.describe TokenManager do
  describe "#token_ttl" do
    it "returns the ttl" do
      token_manager = described_class.new(described_class::DEFAULT_NS, :token_ttl => -> { 60 })

      expect(token_manager.token_ttl).to eq(60)
    end

    it "defaults to 10 minutes" do
      token_manager = described_class.new

      expect(token_manager.token_ttl).to eq(600)
    end

    it "evaluates at call time" do
      stub_settings(:session => {:timeout => 60})
      token_manager = described_class.new(described_class::DEFAULT_NS, :token_ttl => -> { Settings.session.timeout })

      stub_settings(:session => {:timeout => 120})

      expect(token_manager.token_ttl).to eq(120)
    end
  end
end
