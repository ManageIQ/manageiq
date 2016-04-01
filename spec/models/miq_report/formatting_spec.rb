describe MiqReport, "::Formatting" do
  subject { described_class.new(:db => "Vm") }

  describe "#format_currency_with_delimiter" do
    it "adds a prefix and suffix to NumberHelper#number_to_currency" do
      expect(subject.format_currency_with_delimiter(1234567890.50, :prefix => "Front ", :suffix => " Back"))
        .to eq("Front $1,234,567,890.50 Back")
    end
  end

  describe "#format_number_with_delimiter" do
    it "adds a prefix and suffix to NumberHelper#number_with_delimiter" do
      expect(subject.format_number_with_delimiter(12345678, :prefix => "Front ", :suffix => " Back"))
        .to eq("Front 12,345,678 Back")
    end
  end

  describe "#format_mhz_to_human_size" do
    it "adds a prefix and suffix to NumberHelper#mhz_to_human_size" do
      expect(subject.format_mhz_to_human_size(123, :prefix => "Front ", :suffix => " Back"))
        .to eq("Front 123 MHz Back")
    end
  end

  describe "#format_bytes_to_human_size" do
    it "adds a prefix and suffix to NumberHelper#number_to_human_size" do
      expect(subject.format_bytes_to_human_size(123, :prefix => "Front ", :suffix => " Back"))
        .to eq("Front 123 Bytes Back")
    end
  end

  describe "#format_model_name" do
    it "finds human readable name for given model" do
      expect(subject.format_model_name("MiqAction")).to eq("Action")
    end
  end
end
