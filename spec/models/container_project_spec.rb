RSpec.describe ContainerProject do
  subject { FactoryBot.create(:container_project) }

  include_examples "MiqPolicyMixin"

  describe "#all_container_projects" do
    it "returns active and archived records" do
      project = FactoryBot.create(:container_project)
      group_archived = FactoryBot.create(:container_group, :container_project => project, :deleted_on => 1.day.ago.utc)
      group_active = FactoryBot.create(:container_group, :container_project => project)

      expect(project.all_container_groups).to match_array([group_archived, group_active])
    end
  end

  describe "#archived_container_projects" do
    it "returns archived records" do
      project = FactoryBot.create(:container_project)
      group_archived = FactoryBot.create(:container_group, :container_project => project, :deleted_on => 1.day.ago.utc)
      FactoryBot.create(:container_group, :container_project => project)

      expect(project.archived_container_groups).to match_array([group_archived])
    end
  end

  describe "#container_projects" do
    it "returns active records" do
      project = FactoryBot.create(:container_project)
      FactoryBot.create(:container_group, :container_project => project, :deleted_on => 1.day.ago.utc)
      group_active = FactoryBot.create(:container_group, :container_project => project)

      groups = project.container_groups.to_a
      expect(groups).to match_array([group_active])
      expect do
        expect(groups.first.container_project).to eq(project)
      end.not_to make_database_queries
    end
  end
end
