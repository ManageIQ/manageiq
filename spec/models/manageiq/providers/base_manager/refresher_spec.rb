describe ManageIQ::Providers::BaseManager::Refresher do
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

  context "#refresh" do
    context "#preprocess_targets" do
      let(:ems) { FactoryBot.create(:ext_management_system) }
      let(:vm)  { FactoryBot.create(:vm, :ext_management_system => ems) }
      let(:lots_of_vms) do
        num_targets = Settings.ems_refresh.full_refresh_threshold + 1
        Array.new(num_targets) { FactoryBot.create(:vm, :ext_management_system => ems) }
      end

      it "keeps a single vm target" do
        refresher = described_class.new([vm])
        refresher.preprocess_targets

        expect(refresher.targets_by_ems_id[vm.ext_management_system.id]).to eq([vm])
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
