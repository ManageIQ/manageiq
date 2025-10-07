RSpec.describe "ar_references" do
  describe ".prune_references" do
    it "supports none" do
      expect(Vm.prune_references(nil)).to eq({})
      expect(Vm.prune_references([])).to eq({})
    end

    it "supports arrays" do
      expect(Vm.prune_references(%w[host operating_system])).to eq(:host => {}, :operating_system => {})
      expect(Vm.prune_references(%i[host])).to eq(:host => {})
    end

    it "supports hashes" do
      expect(Hardware.prune_references(:vm => {})).to eq(:vm => {})
      expect(Hardware.prune_references(:vm => :ext_management_system)).to eq(:vm => {:ext_management_system => {}})
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
      expect(MiqGroup.prune_references(:tenant => :source)).to eq({:tenant => {}})
    end

    it "skips uses with a polymorphic reference" do
      expect(MetricRollup.prune_references(:v_derived_storage_used => {})).to eq({})
    end
  end
end
