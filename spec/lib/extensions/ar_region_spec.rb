RSpec.describe ArRegion do
  it "exposes #region_number as a virtual column" do
    expect(Vm).to have_virtual_column(:region_number)
  end

  it "exposes #region_description as a virtual column" do
    expect(Vm).to have_virtual_column(:region_description)
  end

  context "#miq_region" do
    before { MiqRegion.seed }

    let!(:vm) { FactoryBot.create(:vm) }

    it "returns the MiqRegion record" do
      expect(vm.miq_region).to eq(MiqRegion.first)
    end

    it "is cached between calls" do
      expect do
        vm.miq_region        # 1 query for miq_region
        vm.reload.miq_region # 1 query for the reload, but *not* for miq_region
      end.to make_database_queries(:count => 2)
    end
  end

  context "#region_description" do
    it "when the region exists" do
      MiqRegion.seed
      vm = FactoryBot.create(:vm)
      expect(vm.region_description).to eq(MiqRegion.first.description)
    end

    it "when the region does not exist" do
      vm = FactoryBot.create(:vm)
      expect(vm.region_description).to be_nil
    end
  end
end
