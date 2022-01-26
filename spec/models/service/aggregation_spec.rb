RSpec.describe Service do
  let(:service) { FactoryBot.create(:service) }
  let(:hardware) { FactoryBot.create(:hardware, :cpu2x2, :memory_mb => 2048) }

  before do
    service << FactoryBot.create(:vm_vmware, :hardware => hardware)
    service.save
  end

  describe "#aggregate_all_vm_memory" do
    it "sql" do
      svc = Service.select(:id, :aggregate_all_vm_memory_on_disk).find_by(:id => service.id)
      expect(svc.aggregate_all_vm_memory).to eq(2048)
      expect(svc.has_attribute?(:aggregate_all_vm_memory_on_disk)).to be(true)
    end

    it "ruby" do
      expect(service.aggregate_all_vm_memory).to eq(2048)
      expect(service.has_attribute?(:aggregate_all_vm_memory_on_disk)).to be(false)
    end
  end

  describe "#aggregate_all_vm_cpus" do
    it "sql" do
      svc = Service.select(:id, :aggregate_all_vm_cpus).find_by(:id => service.id)
      expect(svc.aggregate_all_vm_cpus).to eq(4)
    end

    it "ruby" do
      expect(service.aggregate_all_vm_cpus).to eq(4)
    end
  end

  describe "#aggregate_all_vm_disk_count" do
    before do
      FactoryBot.create_list(:disk, 2, :hardware => hardware, :device_type => 'disk')
    end

    it "sql" do
      svc = Service.select(:id, :aggregate_all_vm_disk_count).find_by(:id => service.id)
      expect(service.aggregate_all_vm_disk_count).to eq(2)
    end

    it "ruby" do
      expect(service.aggregate_all_vm_disk_count).to eq(2)
    end
  end

  describe "#aggregate_all_vm_disk_space_allocated" do
    before do
      FactoryBot.create(:disk, :size_on_disk => 1024, :size => 10_240, :hardware => hardware)
      FactoryBot.create(:disk, :size => 1024, :hardware => hardware)
    end

    it "sql" do
      svc = Service.select(:id, :aggregate_all_vm_disk_space_allocated).find_by(:id => service.id)
      expect(svc.aggregate_all_vm_disk_space_allocated).to eq(11_264)
    end

    it "ruby" do
      expect(service.aggregate_all_vm_disk_space_allocated).to eq(11_264)
    end
  end

  describe "#aggregate_all_vm_memory_on_disk" do
    before do
      FactoryBot.build(:disk, :size_on_disk => 1024, :size => 10_240, :hardware => hardware)
    end

    it "sql" do
      svc = Service.select(:id, :aggregate_all_vm_memory_on_disk).find_by(:id => service.id)
      expect(svc.aggregate_all_vm_memory_on_disk).to eq(2_147_483_648)
    end

    it "ruby" do
      expect(service.aggregate_all_vm_memory_on_disk).to eq(2_147_483_648)
    end
  end
end
