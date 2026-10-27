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

  describe "#parsed_value" do
    it "returns the string value for 'string'" do
      output = described_class.new(:value_type => "string", :value => "hello")
      expect(output.parsed_value).to eq("hello")
    end

    it "casts to integer for 'integer'" do
      output = described_class.new(:value_type => "integer", :value => "42")
      expect(output.parsed_value).to eq(42)
    end

    it "casts to float for 'float'" do
      output = described_class.new(:value_type => "float", :value => "3.14")
      expect(output.parsed_value).to eq(3.14)
    end

    it "parses JSON object for 'object'" do
      output = described_class.new(:value_type => "object", :value => '{"key":"val"}')
      expect(output.parsed_value).to eq("key" => "val")
    end

    it "parses JSON array for 'array'" do
      output = described_class.new(:value_type => "array", :value => '["a","b",1]')
      expect(output.parsed_value).to eq(["a", "b", 1])
    end

    it "casts to boolean for 'boolean'" do
      output = described_class.new(:value_type => "boolean", :value => "true")
      expect(output.parsed_value).to be(true)

      output = described_class.new(:value_type => "boolean", :value => "false")
      expect(output.parsed_value).to be(false)
    end

    it "casts to datetime for 'datetime'" do
      output = described_class.new(:value_type => "datetime", :value => "2026-10-22T19:00:00Z")
      expect(output.parsed_value).to eq(Time.utc(2026, 10, 22, 19, 0, 0))
    end

    it "casts to time for 'time'" do
      output = described_class.new(:value_type => "time", :value => "12:00:00")
      expect(output.parsed_value).to eq(Time.utc(2000, 1, 1, 12, 0, 0))
    end

    it "returns nil for 'null'" do
      output = described_class.new(:value_type => "null", :value => "anything")
      expect(output.parsed_value).to be_nil
    end

    it "returns nil when value is nil" do
      output = described_class.new(:value_type => "integer", :value => nil)
      expect(output.parsed_value).to be_nil
    end
  end
end
