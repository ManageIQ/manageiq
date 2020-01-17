RSpec.describe MiqReport, "::Formatting" do
  subject { described_class.new(:db => "Vm") }

  describe "#format_currency_with_delimiter" do
    it "adds a prefix and suffix to NumberHelper#number_to_currency" do
      expect(subject.format_currency_with_delimiter(1234567890.50, :prefix => "Front ", :suffix => " Back"))
        .to eq("Front $1,234,567,890.50 Back")
    end
    it "puts Dollars as the unit to NumberHelper#number_to_currency" do
      expect(subject.format_currency_with_delimiter(1234567890.50, :unit => "$"))
        .to eq("$1,234,567,890.50")
    end
    it "puts Euro as the unit to NumberHelper#number_to_currency" do
      expect(subject.format_currency_with_delimiter(1234567890.50, :unit => "€"))
        .to eq("€1,234,567,890.50")
    end
    it "puts Pounds as the unit to NumberHelper#number_to_currency" do
      expect(subject.format_currency_with_delimiter(1234567890.50, :unit => "£"))
        .to eq("£1,234,567,890.50")
    end
    it "puts Yen as the unit to NumberHelper#number_to_currency" do
      expect(subject.format_currency_with_delimiter(1234567890.50, :unit => "¥"))
        .to eq("¥1,234,567,890.50")
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

  describe '#format' do
    let(:cores_col) { 'computer_system.hardware.cpu_total_cores' }
    let(:memory_col) { 'computer_system.hardware.memory_mb' }
    let(:container_report) { MiqReport.new(:db => :ContainerNode, :col_order => ['name', cores_col, memory_col]) }

    it 'formats normal integer value' do
      expect(container_report.format(cores_col, 7822)).to eq('7,822')
    end

    it 'formats megabytes value' do
      expect(container_report.format(memory_col, 7822)).to eq('7.6 GB')
    end
  end
end
