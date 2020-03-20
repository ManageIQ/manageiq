RSpec.describe ManageIQ::Providers::BaseManager::Refresher do
  context "#initialize" do
    let(:ems1) { FactoryBot.create(:ext_management_system) }
    let(:ems2) { FactoryBot.create(:ext_management_system) }
    let(:vm1)  { FactoryBot.create(:vm, :ext_management_system => ems1) }
    let(:vm2)  { FactoryBot.create(:vm, :ext_management_system => ems2) }

    it "groups targets by ems" do
      refresher = described_class.new([vm1, vm2])
      expect(refresher.targets_by_ems_id.keys).to include(ems1.id, ems2.id)
    end
  end

  context "#preprocess_targets" do
    let(:ems) { FactoryBot.create(:ext_management_system) }
    let(:vm)  { FactoryBot.create(:vm, :ext_management_system => ems) }
    let(:stack) { FactoryBot.create(:orchestration_stack, :ext_management_system => ems) }
    let(:lots_of_vms) do
      num_targets = Settings.ems_refresh.full_refresh_threshold + 1
      Array.new(num_targets) { FactoryBot.create(:vm, :ext_management_system => ems) }
    end

    context "allow_targeted_refresh true" do
      before { allow(ems).to receive(:allow_targeted_refresh?).and_return(true) }
      it "does full refresh on any event" do
        refresher = described_class.new([vm])
        refresher.preprocess_targets

        targets_by_ems = refresher.targets_by_ems_id[vm.ext_management_system.id].first
        expect(targets_by_ems).to be_a(InventoryRefresh::TargetCollection)
        expect(targets_by_ems.targets.first).to eq(vm)
      end

      it "does a refresh with a stack" do
        refresher = described_class.new([stack])
        refresher.preprocess_targets

        targets_by_ems = refresher.targets_by_ems_id[stack.ext_management_system.id].first
        expect(targets_by_ems).to be_a(InventoryRefresh::TargetCollection)
        expect(targets_by_ems.targets.first).to eq(stack)
      end

      it "does a full refresh with an EMS and a VM" do
        refresher = described_class.new([vm, ems])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[vm.ext_management_system.id]).to eq([ems])
      end

      it "does a full refresh with a lot of targets" do
        refresher = described_class.new(lots_of_vms)
        refresher.preprocess_targets

        targets_by_ems = refresher.targets_by_ems_id[vm.ext_management_system.id].first
        expect(targets_by_ems).to be_a(InventoryRefresh::TargetCollection)
        expect(targets_by_ems.targets.count).to eq(101)
      end
    end

    context "allow_targeted_refresh false" do
      before { allow(ems).to receive(:allow_targeted_refresh?).and_return(false) }
      it "keeps a single vm target" do
        refresher = described_class.new([vm])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[vm.ext_management_system.id]).to eq([ems])
      end

      it "does a refresh with a stack" do
        refresher = described_class.new([stack])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[stack.ext_management_system.id].first).to eq(ems)
      end

      it "does a full refresh with an EMS and a VM" do
        refresher = described_class.new([vm, ems])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[vm.ext_management_system.id]).to eq([ems])
      end

      it "does a full refresh with a lot of targets" do
        refresher = described_class.new(lots_of_vms)
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[ems.id]).to eq([ems])
      end
    end
  end
end
