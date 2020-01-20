RSpec.describe "ar_references" do
  describe ".includes_to_references" do
    it "supports none" do
      expect(Vm.includes_to_references(nil)).to eq([])
      expect(Vm.includes_to_references([])).to eq([])
    end

    it "supports arrays" do
      expect(Vm.includes_to_references(%w[host operating_system])).to eq(%w[hosts operating_systems])
      expect(Vm.includes_to_references(%i[host])).to eq(%w[hosts])
    end

    it "supports hashes" do
      expect(Hardware.includes_to_references(:vm => {})).to eq(%w[vms])
      expect(Hardware.includes_to_references(:vm => :ext_management_system)).to eq(%w[vms ext_management_systems])
      expect(Hardware.includes_to_references(:vm => {:ext_management_system => {}})).to eq(%w[vms ext_management_systems])
    end

    it "supports table array" do
      expect(Vm.includes_to_references(%w[hosts operating_systems])).to eq(%w[hosts operating_systems])
    end
  end
end
