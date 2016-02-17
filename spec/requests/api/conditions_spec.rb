#
# REST API Request Tests - Conditions
#
# Condition primary collection:
#   /api/conditions
#
# Condition subcollection:
#   /api/policies/:id/conditions
#
describe ApiController do
  let(:condition_guid_list) { Condition.pluck(:guid) }

  def create_conditions(count)
    count.times { FactoryGirl.create(:condition) }
  end

  def assign_conditions_to(resource)
    resource.conditions = Condition.all
  end

  context "Condition collection" do
    it "query invalid collection" do
      api_basic_authorize

      run_get conditions_url(999_999)

      expect_resource_not_found
    end

    it "query conditions with no conditions defined" do
      api_basic_authorize

      run_get conditions_url

      expect_empty_query_result(:conditions)
    end

    it "query conditions" do
      api_basic_authorize
      create_conditions(3)

      run_get conditions_url

      expect_query_result(:conditions, 3, 3)
      expect_result_resources_to_include_hrefs("resources",
                                               Condition.pluck(:id).collect { |id| /^.*#{conditions_url(id)}$/ })
    end

    it "query conditions in expanded form" do
      api_basic_authorize
      create_conditions(3)

      run_get conditions_url, :expand => "resources"

      expect_query_result(:conditions, 3, 3)
      expect_result_resources_to_include_data("resources", "guid" => :condition_guid_list)
    end
  end

  context "Condition subcollection" do
    let(:policy)                { FactoryGirl.create(:miq_policy, :name => "Policy 1") }
    let(:policy_url)            { policies_url(policy.id) }
    let(:policy_conditions_url) { "#{policy_url}/conditions" }

    it "query conditions with no conditions defined" do
      api_basic_authorize

      run_get policy_conditions_url

      expect_empty_query_result(:conditions)
    end

    it "query conditions" do
      api_basic_authorize
      create_conditions(3)
      assign_conditions_to(policy)

      run_get policy_conditions_url, :expand => "resources"

      expect_query_result(:conditions, 3, 3)
      expect_result_resources_to_include_data("resources", "guid" => :condition_guid_list)
    end

    it "query policy with expanded conditions" do
      api_basic_authorize
      create_conditions(3)
      assign_conditions_to(policy)

      run_get policy_url, :expand => "conditions"

      expect_single_resource_query("name" => policy.name, "description" => policy.description, "guid" => policy.guid)
      expect_result_resources_to_include_data("conditions", "guid" => :condition_guid_list)
    end
  end
end
