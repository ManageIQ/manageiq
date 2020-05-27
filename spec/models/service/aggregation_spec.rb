RSpec.describe Service do
  let(:service) { FactoryBot.create(:service) }
  let(:hardware) { FactoryBot.create(:hardware, :cpu2x2, :memory_mb => 2048) }

  before do
    service << FactoryBot.create(:vm_vmware, :hardware => hardware)
    service.save
  end

  it "#aggregate_all_vm_memory_on_disk will not raise when the attribute is nil" do
    expect(service).to receive(:has_attribute?).with("aggregate_all_vm_memory_on_disk").and_return(true)
    expect { service.aggregate_all_vm_memory_on_disk }.not_to raise_error
  end

  it "#aggregate_all_vm_memory" do
    expect(service.aggregate_all_vm_memory).to eq(2048)
  end

  it "#aggregate_all_vm_cpus" do
    expect(service.aggregate_all_vm_cpus).to eq(4)
  end

  it "#aggregate_all_vm_disk_count" do
    FactoryBot.create_list(:disk, 2, :hardware => hardware, :device_type => 'disk')

    expect(service.aggregate_all_vm_disk_count).to eq(2)
  end

  it "#aggregate_all_vm_disk_space_allocated" do
    FactoryBot.create(:disk, :size_on_disk => 1024, :size => 10_240, :hardware => hardware)
    FactoryBot.create(:disk, :size => 1024, :hardware => hardware)

    expect(service.aggregate_all_vm_disk_space_allocated).to eq(11_264)
  end

  it "#aggregate_all_vm_memory_on_disk" do
    FactoryBot.build(:disk, :size_on_disk => 1024, :size => 10_240, :hardware => hardware)

    expect(service.aggregate_all_vm_memory_on_disk).to eq(2_147_483_648)
  end
end
