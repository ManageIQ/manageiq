describe Metric::ConfigSettings do
  before(:each) do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  it ".host_overhead_cpu" do
    config = VMDB::Config.new("vmdb")

    config.config.store_path(:performance, :host_overhead, :cpu, 1.23)
    config.save
    expect(described_class.host_overhead_cpu).to eq(1.23)

    config.config.delete_path(:performance, :host_overhead)
    config.save
    expect(described_class.host_overhead_cpu).to eq(0.15)
  end

  it ".host_overhead_memory" do
    config = VMDB::Config.new("vmdb")

    config.config.store_path(:performance, :host_overhead, :memory, 1.23)
    config.save
    expect(described_class.host_overhead_memory).to eq(1.23)

    config.config.delete_path(:performance, :host_overhead)
    config.save
    expect(described_class.host_overhead_memory).to eq(2.01)
  end
end
