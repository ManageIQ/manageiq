RSpec.describe ContainerService do
  let(:group) { FactoryBot.create(:container_group_with_assoc) }
  let(:ems) { group.ext_management_system }
  let(:project) { group.container_project }
  let(:service) { FactoryBot.create(:container_service, :ext_management_system => ems, :container_project => project) }

  describe "#container_groups_count" do
    it "counts singles" do
      service.container_groups << group
      expect(service.reload.container_groups_count).to eq(1)
    end
  end
end
