RSpec.describe OrchestrationStackOutput do
  describe "#value_type" do
    it "defaults to 'string'" do
      expect(described_class.new.value_type).to eq("string")
    end

    %w[string integer float object array boolean datetime time null].each do |val|
      it "allows #{val.inspect}" do
        output = described_class.new(:value_type => val)
        output.validate
        expect(output.errors[:value_type]).to be_empty
      end
    end

    it "disallows invalid value_types" do
      output = described_class.new(:value_type => "invalid")
      output.validate
      expect(output.errors[:value_type]).to include("is not included in the list")
    end

    it "disallows nil" do
      output = described_class.new(:value_type => nil)
      output.validate
      expect(output.errors[:value_type]).to include("is not included in the list")
    end
  end
end
