RSpec.describe ConfiguredSystem do
  include Spec::Support::ArelHelper

  it "#counterparts" do
    vm  = FactoryBot.create(:vm)
    cs1 = FactoryBot.create(:configured_system, :counterpart => vm)
    cs2 = FactoryBot.create(:configured_system, :counterpart => vm)
    cs3 = FactoryBot.create(:configured_system, :counterpart => vm)

    expect(cs1.counterparts).to match_array([vm, cs2, cs3])
  end

  describe "#inventory_root_group_name" do
    context "with no inventory root group" do
      subject { FactoryBot.create(:configured_system) }
      it_behaves_like "sql friendly virtual_attribute", :inventory_root_group_name, nil
    end

    subject { FactoryBot.create(:configured_system, :inventory_root_group => FactoryBot.create(:ems_folder, :name => 'folder_name')) }
    it_behaves_like "sql friendly virtual_attribute", :inventory_root_group_name, 'folder_name'
  end

  describe "#queue_name_for_ems_operations" do
    context "with an active configured_system" do
      let(:manager)           { FactoryBot.create(:configuration_manager) }
      let(:configured_system) { FactoryBot.create(:configured_system, :manager => manager) }

      it "uses the manager's queue_name_for_ems_operations" do
        expect(configured_system.queue_name_for_ems_operations).to eq(manager.queue_name_for_ems_operations)
      end
    end

    context "with an archived configured_system" do
      let(:configured_system) { FactoryBot.create(:configured_system) }

      it "uses the manager's queue_name_for_ems_operations" do
        expect(configured_system.queue_name_for_ems_operations).to be_nil
      end
    end
  end
end
