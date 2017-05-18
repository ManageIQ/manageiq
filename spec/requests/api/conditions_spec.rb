#
# REST API Request Tests - Conditions
#
# Condition primary collection:
#   /api/conditions
#
# Condition subcollection:
#   /api/policies/:id/conditions
#
describe "Conditions API" do
  let(:condition_guid_list) { Condition.pluck(:guid) }

  def create_conditions(count)
    count.times { FactoryGirl.create(:condition) }
  end

  def assign_conditions_to(resource)
    resource.conditions = Condition.all
  end

  context "Condition CRUD" do
    let(:sample_condition) do
      {
        :name        => "name",
        :description => "description",
        :expression  => {"=" => {"field" => "ContainerImage-architecture", "value" => "dsa"}},
        :towhat      => "ExtManagementSystem",
        :modifier    => "allow"
      }
    end
    let(:condition) { FactoryGirl.create(:condition) }
    let(:condition_url) { conditions_url(condition.id) }
    let(:conditions) { FactoryGirl.create_list(:condition, 2) }

    it "forbids access to create condition without an appropriate role" do
      api_basic_authorize

      run_post(conditions_url, sample_condition)

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids access to edit condition without an appropriate role" do
      api_basic_authorize

      run_post(conditions_url(condition.id), gen_request(:edit, "description" => "change"))

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids access to delete condition without an appropriate role" do
      condition
      api_basic_authorize

      run_post(conditions_url, gen_request(:delete, "name" => condition.name, "href" => condition_url))

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids access to read condition without an appropriate role" do
      condition
      api_basic_authorize

      run_get conditions_url

      expect(response).to have_http_status(:forbidden)
    end

    it "creates new condition" do
      api_basic_authorize collection_action_identifier(:conditions, :create)
      run_post(conditions_url, sample_condition)

      expect(response).to have_http_status(:ok)

      condition_id = response.parsed_body["results"].first["id"]

      expect(Condition.exists?(condition_id)).to be_truthy
      expect(Condition.find(condition_id).expression.class).to eq(MiqExpression)
    end

    it "creates new conditions" do
      api_basic_authorize collection_action_identifier(:conditions, :create)
      run_post(conditions_url, gen_request(:create, [sample_condition,
                                                     sample_condition.merge(:name => "foo", :description => "bar")]))
      expect(response).to have_http_status(:ok)

      expect(response.parsed_body["results"].count).to eq(2)
    end

    it "deletes condition" do
      api_basic_authorize collection_action_identifier(:conditions, :delete)
      run_post(conditions_url, gen_request(:delete, "name" => condition.name, "href" => condition_url))

      expect(response).to have_http_status(:ok)

      expect(Condition.exists?(condition.id)).to be_falsey
    end

    it "deletes conditions" do
      api_basic_authorize collection_action_identifier(:conditions, :delete)
      run_post(conditions_url, gen_request(:delete, [{"name" => conditions.first.name,
                                                      "href" => conditions_url(conditions.first.id)},
                                                     {"name" => conditions.second.name,
                                                      "href" => conditions_url(conditions.second.id)}]))

      expect(response).to have_http_status(:ok)

      expect(response.parsed_body["results"].count).to eq(2)
    end

    it "deletes condition via DELETE" do
      api_basic_authorize collection_action_identifier(:conditions, :delete)

      run_delete(conditions_url(condition.id))

      expect(response).to have_http_status(:no_content)
      expect(Condition.exists?(condition.id)).to be_falsey
    end

    it "edits condition" do
      api_basic_authorize collection_action_identifier(:conditions, :edit)
      run_post(conditions_url(condition.id), gen_request(:edit, "description" => "change"))

      expect(response).to have_http_status(:ok)

      expect(Condition.find(condition.id).description).to eq("change")
      expect(Condition.find(condition.id).expression.class).to eq(MiqExpression)
    end

    it "edits conditions" do
      api_basic_authorize collection_action_identifier(:conditions, :edit)
      run_post(conditions_url, gen_request(:edit, [{"id" => conditions.first.id, "description" => "change"},
                                                   {"id" => conditions.second.id, "description" => "change2"}]))
      expect(response).to have_http_status(:ok)

      expect(response.parsed_body["results"].count).to eq(2)

      expect(Condition.pluck(:description)).to match_array(%w(change change2))
    end
  end

  context "Condition collection" do
    it "query invalid collection" do
      api_basic_authorize collection_action_identifier(:conditions, :read, :get)

      run_get conditions_url(999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "query conditions with no conditions defined" do
      api_basic_authorize collection_action_identifier(:conditions, :read, :get)

      run_get conditions_url

      expect_empty_query_result(:conditions)
    end

    it "query conditions" do
      api_basic_authorize collection_action_identifier(:conditions, :read, :get)
      create_conditions(3)

      run_get conditions_url

      expect_query_result(:conditions, 3, 3)
      expect_result_resources_to_include_hrefs("resources",
                                               Condition.pluck(:id).collect { |id| /^.*#{conditions_url(id)}$/ })
    end

    it "query conditions in expanded form" do
      api_basic_authorize collection_action_identifier(:conditions, :read, :get)
      create_conditions(3)

      run_get conditions_url, :expand => "resources"

      expect_query_result(:conditions, 3, 3)
      expect_result_resources_to_include_data("resources", "guid" => condition_guid_list)
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
      expect_result_resources_to_include_data("resources", "guid" => condition_guid_list)
    end

    it "query policy with expanded conditions" do
      api_basic_authorize action_identifier(:policies, :read, :resource_actions, :get)
      create_conditions(3)
      assign_conditions_to(policy)

      run_get policy_url, :expand => "conditions"

      expect_single_resource_query("name" => policy.name, "description" => policy.description, "guid" => policy.guid)
      expect_result_resources_to_include_data("conditions", "guid" => condition_guid_list)
    end
  end
end
