RSpec.describe PhysicalServerProfile do
  describe "#queue_name_for_ems_operations" do
    context "with an active physical_server_profile" do
      let(:manager)                 { FactoryBot.create(:physical_infra) }
      let(:physical_server_profile) { FactoryBot.create(:physical_server_profile, :ext_management_system => manager) }

      it "uses the manager's queue_name_for_ems_operations" do
        expect(physical_server_profile.queue_name_for_ems_operations).to eq(manager.queue_name_for_ems_operations)
      end
    end

    context "with a physical_server_profile without an ext_management_system" do
      let(:physical_server_profile) { FactoryBot.create(:physical_server_profile) }

      it "uses the manager's queue_name_for_ems_operations" do
        expect(physical_server_profile.queue_name_for_ems_operations).to be_nil
      end
    end
  end
end
