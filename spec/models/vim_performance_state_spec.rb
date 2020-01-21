RSpec.describe VimPerformanceState do
  describe ".capture_host_sockets" do
    it "returns the host sockets when given a host" do
      hardware = FactoryBot.build(:hardware, :cpu_sockets => 2)
      host = FactoryBot.create(:host, :hardware => hardware)
      state = VimPerformanceState.capture(host)

      expect(state.host_sockets).to eq(2)
    end

    it "rolls up the total sockets when given something that has hosts" do
      hardware_1 = FactoryBot.build(:hardware, :cpu_sockets => 2)
      hardware_2 = FactoryBot.build(:hardware, :cpu_sockets => 4)
      host_1 = FactoryBot.build(:host, :hardware => hardware_1)
      host_2 = FactoryBot.build(:host, :hardware => hardware_2)
      cluster = FactoryBot.create(:ems_cluster, :hosts => [host_1, host_2])
      state = VimPerformanceState.capture(cluster)

      expect(state.host_sockets).to eq(6)
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

  describe '#allocated_disk_types' do
    let(:ssd_size) { 1_234 }
    let(:hdd1_size) { 5_678 }
    let(:hdd2_size) { 9_101 }
    let(:ssd_volume) { FactoryBot.create(:cloud_volume_openstack, :volume_type => 'ssd') }
    let(:ssd_disk) { FactoryBot.create(:disk, :size => ssd_size, :backing => ssd_volume) }
    let(:hdd_volume) { FactoryBot.create(:cloud_volume_openstack, :volume_type => nil) }
    let(:hdd1_disk) { FactoryBot.create(:disk, :size => hdd1_size, :backing => hdd_volume) }
    let(:hdd2_disk) { FactoryBot.create(:disk, :size => hdd2_size) }
    let(:hardware) { FactoryBot.create(:hardware, :disks => [ssd_disk, hdd1_disk, hdd2_disk]) }
    let(:vm) { FactoryBot.create(:vm_openstack, :hardware => hardware) }

    subject { vm.perf_capture_state.allocated_disk_types }

    it { is_expected.to match('ssd' => ssd_size, 'unclassified' => hdd1_size + hdd2_size) }

    context 'when disk size is nil' do
      let!(:hdd1_disk) { FactoryBot.create(:disk, :size => nil, :backing => hdd_volume) }

      it { is_expected.to match('ssd' => ssd_size, 'unclassified' => hdd2_size) }

      context "when all disk's sizes are nil" do
        let!(:hdd2_disk) { FactoryBot.create(:disk, :size => nil, :backing => hdd_volume) }
        let!(:ssd_disk)  { FactoryBot.create(:disk, :size => nil, :backing => ssd_volume) }

        it { is_expected.to be_empty }
      end
    end
  end
end
