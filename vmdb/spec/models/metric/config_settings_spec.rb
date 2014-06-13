require "spec_helper"

describe Metric::ConfigSettings do
  before(:each) do
    EvmSpecHelper.seed_for_miq_queue # TODO: Rename this method
  end

  it ".host_overhead_cpu" do
    config = VMDB::Config.new("vmdb")

    config.config.store_path(:performance, :host_overhead, :cpu, 1.23)
    config.save
    described_class.host_overhead_cpu.should == 1.23

    config.config.delete_path(:performance, :host_overhead)
    config.save
    described_class.host_overhead_cpu.should == 0.15
  end

  it ".host_overhead_memory" do
    config = VMDB::Config.new("vmdb")

    config.config.store_path(:performance, :host_overhead, :memory, 1.23)
    config.save
    described_class.host_overhead_memory.should == 1.23

    config.config.delete_path(:performance, :host_overhead)
    config.save
    described_class.host_overhead_memory.should == 2.01
  end
end
