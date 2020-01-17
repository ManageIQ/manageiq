RSpec.describe Metric::ConfigSettings do
  before do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  describe ".host_overhead_cpu" do
    it "overridden in settings" do
      stub_settings(:performance => {:host_overhead => {:cpu => 1.23}})
      expect(described_class.host_overhead_cpu).to eq(1.23)
    end

  end

  describe ".host_overhead_memory" do
    it "overridden in settings" do
      stub_settings(:performance => {:host_overhead => {:memory => 1.23}})
      expect(described_class.host_overhead_memory).to eq(1.23)
    end

  end
end
