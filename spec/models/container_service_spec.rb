RSpec.describe ContainerService do
  let(:group) { FactoryBot.create(:container_group_with_assoc) }
  let(:ems) { group.ext_management_system }
  let(:project) { group.container_project }
  let(:service) { FactoryBot.create(:container_service, :ext_management_system => ems, :container_project => project) }

  describe "#container_groups_count" do
    subject { service.tap { service.container_groups << group } }

    # NOTE: virtual_total does not currently work with habtm
    it_behaves_like "ruby only virtual_attribute", :container_groups_count, 1
  end
end
