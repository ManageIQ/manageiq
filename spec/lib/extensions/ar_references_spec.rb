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

    it "skips tags" do
      expect(Vm.includes_to_references(:taggings => {})).to eq([])
    end

    it "skips virtual has many" do
      expect(Vm.includes_to_references(:processes => {})).to eq([])
    end

    it "skips virtual attributes" do
      expect(Vm.includes_to_references(:archived => {}, :platform => {})).to eq([])
    end

    it "skips polymorphic references" do
      expect(MetricRollup.includes_to_references(:resource=>{})).to eq([])
      expect(MiqGroup.includes_to_references(:tenant => :source)).to eq(%w[tenants])
    end

    it "skips uses with a polymorphic reference" do
      expect(MetricRollup.includes_to_references(:v_derived_storage_used => {})).to eq([])
    end
  end

  describe ".prune_references" do
    it "supports none" do
      expect(Vm.prune_references(nil)).to eq({})
      expect(Vm.prune_references([])).to eq([])
    end

    it "supports arrays" do
      expect(Vm.prune_references(%w[host operating_system])).to eq([:host, :operating_system])
      expect(Vm.prune_references(%i[host])).to eq([:host])
    end

    it "supports hashes" do
      expect(Hardware.prune_references(:vm => {})).to eq(:vm => {})
      expect(Hardware.prune_references(:vm => :ext_management_system)).to eq(:vm => [:ext_management_system])
      expect(Hardware.prune_references(:vm => {:ext_management_system => {}})).to eq(:vm => {:ext_management_system => {}})
    end

    it "skips tags" do
      expect(Vm.prune_references(:taggings => {})).to eq({})
    end

    it "skips virtual has many" do
      expect(Vm.prune_references(:processes => {})).to eq({})
    end

    it "skips virtual attributes" do
      expect(Vm.prune_references(:archived => {}, :platform => {})).to eq({})
    end

    it "skips polymorphic references" do
      expect(MetricRollup.prune_references(:resource=>{})).to eq({})
      expect(MiqGroup.prune_references(:tenant => :source)).to eq({:tenant => []})
    end

    it "skips uses with a polymorphic reference" do
      expect(MetricRollup.prune_references(:v_derived_storage_used => {})).to eq({})
    end
  end
end
