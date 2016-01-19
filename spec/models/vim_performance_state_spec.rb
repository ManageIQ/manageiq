RSpec.describe VimPerformanceState do
  describe ".capture_host_sockets" do
    it "returns the host sockets when given a host" do
      hardware = FactoryGirl.build(:hardware, :cpu_sockets => 2)
      host = FactoryGirl.build(:host, :hardware => hardware)

      expect(described_class.capture_host_sockets(host)).to eq(2)
    end

    it "rolls up the total sockets when given something that has hosts" do
      hardware_1 = FactoryGirl.build(:hardware, :cpu_sockets => 2)
      hardware_2 = FactoryGirl.build(:hardware, :cpu_sockets => 4)
      host_1 = FactoryGirl.build(:host, :hardware => hardware_1)
      host_2 = FactoryGirl.build(:host, :hardware => hardware_2)
      cluster = FactoryGirl.create(:ems_cluster, :hosts => [host_1, host_2])

      expect(described_class.capture_host_sockets(cluster)).to eq(6)
    end
  end

  describe "#vm_count_total" do
    it "will return the total vms regardless of mode" do
      state_data = {:assoc_ids => {:vms => {:on => [1], :off => [2]}}}
      actual = described_class.new(:state_data => state_data)
      expect(actual.vm_count_total).to eq(2)
    end
  end

  describe "#host_count_total" do
    it "will return the total hosts regardless of mode" do
      state_data = {:assoc_ids => {:hosts => {:on => [1], :off => [2]}}}
      actual = described_class.new(:state_data => state_data)
      expect(actual.host_count_total).to eq(2)
    end
  end

  describe "#host_sockets" do
    it "returns the host sockets" do
      state_data = {:host_sockets => 2}
      actual = described_class.new(:state_data => state_data)
      expect(actual.host_sockets).to eq(2)
    end
  end
end
