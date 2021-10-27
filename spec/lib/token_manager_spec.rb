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

  describe "#token_valid?" do
    let(:token_store) { double("FakeTokenStore") }

    it "raises MissingTokenError if token is nil" do
      expect { subject.token_valid?(nil) }.to raise_error(described_class::MissingTokenError)
    end

    it "raises EmptyTokenError if token is empty" do
      expect { subject.token_valid?("") }.to raise_error(described_class::EmptyTokenError)
    end

    it "returns true if the token exists" do
      token = "token"

      expect(subject).to     receive(:token_store).and_return(token_store)
      expect(token_store).to receive(:read).with(token).and_return("foo")

      expect(subject.token_valid?(token)).to eq(true)
    end

    it "returns false if the token does not exist" do
      token = "not_a_token"

      expect(subject).to     receive(:token_store).and_return(token_store)
      expect(token_store).to receive(:read).with(token).and_return(nil)

      expect(subject.token_valid?(token)).to eq(false)
    end
  end
end
