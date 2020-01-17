RSpec.describe Chargeback::ConsumptionWithoutRollups do
  let(:cores) { 7 }
  let(:mem_mb) { 1777 }
  let(:disk_size) { 12_345 }
  let(:hardware) do
    FactoryBot.build(:hardware,
                      :cpu_total_cores => cores,
                      :memory_mb       => mem_mb,
                      :disks           => [FactoryBot.build(:disk, :size => disk_size)])
  end
  let(:vm) { FactoryBot.build(:vm_microsoft, :hardware => hardware) }
  let(:consumption) { described_class.new(vm, nil, nil) }

  describe '#avg' do
    it 'returns current values' do
      expect(consumption.avg('derived_vm_numvcpus')).to eq(cores)
      expect(consumption.avg('derived_memory_available')).to eq(mem_mb)
      expect(consumption.avg('derived_vm_allocated_disk_storage')).to eq(disk_size)
    end
  end
end
