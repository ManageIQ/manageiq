#
# REST API Request Tests - Policy Actions
#
# Policy Action primary collection:
#   /api/policy_actions
#
# Policy Action subcollection:
#   /api/policies/:id/policy_actions
#
describe ApiController do
  let(:miq_action_guid_list) { MiqAction.pluck(:guid) }

  def create_actions(count)
    1.upto(count) do |i|
      FactoryGirl.create(:miq_action, :name => "custom_action_#{i}", :description => "Custom Action #{i}")
    end
  end

  context "Policy Action collection" do
    it "query invalid action" do
      api_basic_authorize

      run_get policy_actions_url(999_999)

      expect_resource_not_found
    end

    it "query policy actions with no actions defined" do
      api_basic_authorize

      run_get policy_actions_url

      expect_empty_query_result(:policy_actions)
    end

    it "query policy actions" do
      api_basic_authorize
      create_actions(4)

      run_get policy_actions_url

      expect_query_result(:policy_actions, 4, 4)
      expect_result_resources_to_include_hrefs("resources",
                                               MiqAction.pluck(:id).collect { |id| /^.*#{policy_actions_url(id)}$/ })
    end

    it "query policy actions in expanded form" do
      api_basic_authorize
      create_actions(4)

      run_get policy_actions_url, :expand => "resources"

      expect_query_result(:policy_actions, 4, 4)
      expect_result_resources_to_include_data("resources", "guid" => :miq_action_guid_list)
    end
  end

  context "Policy Action subcollection" do
    let(:policy)             { FactoryGirl.create(:miq_policy, :name => "Policy 1") }
    let(:policy_url)         { policies_url(policy.id) }
    let(:policy_actions_url) { "#{policy_url}/policy_actions" }

    def relate_actions_to(policy)
      MiqAction.all.collect(&:id).each do |action_id|
        MiqPolicyContent.create(:miq_policy_id => policy.id, :miq_action_id => action_id)
      end
    end

    it "query policy actions with no actions defined" do
      api_basic_authorize

      run_get policy_actions_url

      expect_empty_query_result(:policy_actions)
    end

    it "query policy actions" do
      api_basic_authorize
      create_actions(4)
      relate_actions_to(policy)

      run_get policy_actions_url, :expand => "resources"

      expect_query_result(:policy_actions, 4, 4)
      expect_result_resources_to_include_data("resources", "guid" => :miq_action_guid_list)
    end

    it "query policy with expanded policy actions" do
      api_basic_authorize action_identifier(:policies, :read, :resource_actions, :get)
      create_actions(4)
      relate_actions_to(policy)

      run_get policy_url, :expand => "policy_actions"

      expect_single_resource_query("name" => policy.name, "description" => policy.description, "guid" => policy.guid)
      expect_result_resources_to_include_data("policy_actions", "guid" => :miq_action_guid_list)
    end
  end
end
