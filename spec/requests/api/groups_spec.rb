#
# Rest API Request Tests - Groups specs
#
# - Creating a group                      /api/groups                           POST
# - Creating a group via action           /api/groups                           action "create"
# - Creating multiple groups              /api/groups                           action "create"
# - Edit a group                          /api/groups/:id                       action "edit"
# - Edit multiple groups                  /api/groups                           action "edit"
# - Delete a group                        /api/groups/:id                       DELETE
# - Delete a group by action              /api/groups/:id                       action "delete"
# - Delete multiple groups                /api/groups                           action "delete"
#
describe "Groups API" do
  let(:expected_attributes) { %w(id description group_type tenant_id) }

  let(:sample_group1) { {:description => "sample_group_1"} }
  let(:sample_group2) { {:description => "sample_group_2"} }
  let(:group1) { FactoryGirl.create(:miq_group, sample_group1) }
  let(:group2) { FactoryGirl.create(:miq_group, sample_group2) }

  let(:role3)    { FactoryGirl.create(:miq_user_role) }
  let(:tenant3)  { FactoryGirl.create(:tenant, :name => "Tenant3") }

  describe "groups create" do
    it "rejects creation without appropriate role" do
      api_basic_authorize

      run_post(groups_url, sample_group1)

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects group creation with id specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      run_post(groups_url, "description" => "sample group", "id" => 100)

      expect_bad_request(/id or href should not be specified/i)
    end

    it "rejects group creation with invalid role specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      run_post(groups_url, "description" => "sample group", "role" => {"id" => 999_999})

      expect(response).to have_http_status(:not_found)
    end

    it "rejects group creation with invalid tenant specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      run_post(groups_url, "description" => "sample group", "tenant" => {"id" => 999_999})

      expect(response).to have_http_status(:not_found)
    end

    it "rejects group creation with invalid filters specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      run_post(groups_url, "description" => "sample group", "filters" => {"bogus" => %w(f1 f2)})

      expect_bad_request(/Invalid filter/i)
    end

    it "supports single group creation" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      run_post(groups_url, sample_group1)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      group_id = response.parsed_body["results"].first["id"]
      expect(MiqGroup.exists?(group_id)).to be_truthy
    end

    it "supports single group creation via action" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      run_post(groups_url, gen_request(:create, sample_group1))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      group_id = response.parsed_body["results"].first["id"]
      expect(MiqGroup.exists?(group_id)).to be_truthy
    end

    it "supports single group creation via action with role and tenant specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      run_post(groups_url, gen_request(:create,
                                       "description" => "sample_group3",
                                       "role"        => {"name" => role3.name},
                                       "tenant"      => {"href" => tenants_url(tenant3.id)}))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      result = response.parsed_body["results"].first
      created_group = MiqGroup.find_by(:id => result["id"])

      expect(created_group).to be_present
      expect(created_group.entitlement.miq_user_role).to eq(role3)

      expect_result_to_match_hash(result,
                                  "description"      => "sample_group3",
                                  "tenant_id"        => tenant3.id)
    end

    it "supports single group creation with filters specified" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      sample_group = {"description" => "sample_group3",
                      "filters"     => {
                        "managed"   => [["/managed/area/1", "/managed/area/2"]],
                        "belongsto" => ["/managed/infra/1", "/managed/infra/2"],
                      }
      }
      run_post(groups_url, gen_request(:create, sample_group))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      group_id = response.parsed_body["results"][0]["id"]
      expected_group = MiqGroup.find_by(:id => group_id)
      expect(expected_group).to be_present
      expect(expected_group.description).to eq(sample_group["description"])
      expect(expected_group.entitlement).to be_present
      expect(expected_group.entitlement.filters).to eq(sample_group["filters"])
    end

    it "supports multiple group creation" do
      api_basic_authorize collection_action_identifier(:groups, :create)

      run_post(groups_url, gen_request(:create, [sample_group1, sample_group2]))

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_attributes)

      results = response.parsed_body["results"]
      group1_id = results.first["id"]
      group2_id = results.second["id"]
      expect(MiqGroup.exists?(group1_id)).to be_truthy
      expect(MiqGroup.exists?(group2_id)).to be_truthy
    end
  end

  describe "groups edit" do
    it "rejects group edits without appropriate role" do
      api_basic_authorize
      run_post(groups_url, gen_request(:edit,
                                       "description" => "updated_group",
                                       "href"        => groups_url(group1.id)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects group edits for invalid resources" do
      api_basic_authorize collection_action_identifier(:groups, :edit)

      run_post(groups_url(999_999), gen_request(:edit, "description" => "updated_group"))

      expect(response).to have_http_status(:not_found)
    end

    it "supports single group edit" do
      api_basic_authorize collection_action_identifier(:groups, :edit)

      run_post(groups_url(group1.id), gen_request(:edit, "description" => "updated_group"))

      expect_single_resource_query("id"          => group1.id,
                                   "description" => "updated_group")
      expect(group1.reload.description).to eq("updated_group")
    end

    it "supports multiple group edits" do
      api_basic_authorize collection_action_identifier(:groups, :edit)

      run_post(groups_url, gen_request(:edit,
                                       [{"href" => groups_url(group1.id), "description" => "updated_group1"},
                                        {"href" => groups_url(group2.id), "description" => "updated_group2"}]))

      expect_results_to_match_hash("results",
                                   [{"id" => group1.id, "description" => "updated_group1"},
                                    {"id" => group2.id, "description" => "updated_group2"}])

      expect(group1.reload.name).to eq("updated_group1")
      expect(group2.reload.name).to eq("updated_group2")
    end
  end

  describe "groups delete" do
    it "rejects group deletion, by post action, without appropriate role" do
      api_basic_authorize

      run_post(groups_url, gen_request(:delete, "description" => "group_description", "href" => groups_url(100)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects group deletion without appropriate role" do
      api_basic_authorize

      run_delete(groups_url(100))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects group deletes for invalid groups" do
      api_basic_authorize collection_action_identifier(:groups, :delete)

      run_delete(groups_url(999_999))

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a request to remove a default tenant group' do
      api_basic_authorize collection_action_identifier(:groups, :delete)

      run_delete(groups_url(tenant3.default_miq_group_id))

      expect(response).to have_http_status(:forbidden)
    end

    it "supports single group delete" do
      api_basic_authorize collection_action_identifier(:groups, :delete)

      g1_id = group1.id
      run_delete(groups_url(g1_id))

      expect(response).to have_http_status(:no_content)
      expect(MiqGroup.exists?(g1_id)).to be_falsey
    end

    it "supports single group delete action" do
      api_basic_authorize collection_action_identifier(:groups, :delete)

      g1_id = group1.id
      g1_url = groups_url(g1_id)

      run_post(g1_url, gen_request(:delete))

      expect_single_action_result(:success => true, :message => "deleting", :href => g1_url)
      expect(MiqGroup.exists?(g1_id)).to be_falsey
    end

    it "supports multiple group deletes" do
      api_basic_authorize collection_action_identifier(:groups, :delete)

      g1_id, g2_id = group1.id, group2.id
      g1_url, g2_url = groups_url(g1_id), groups_url(g2_id)

      run_post(groups_url, gen_request(:delete, [{"href" => g1_url}, {"href" => g2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", [g1_url, g2_url])
      expect(MiqGroup.exists?(g1_id)).to be_falsey
      expect(MiqGroup.exists?(g2_id)).to be_falsey
    end
  end

  describe "tags subcollection" do
    it "can list a group's tags" do
      group = FactoryGirl.create(:miq_group)
      FactoryGirl.create(:classification_department_with_tags)
      Classification.classify(group, "department", "finance")
      api_basic_authorize

      run_get("#{groups_url(group.id)}/tags")

      expect(response.parsed_body).to include("subcount" => 1)
      expect(response).to have_http_status(:ok)
    end

    it "can assign a tag to a group" do
      group = FactoryGirl.create(:miq_group)
      FactoryGirl.create(:classification_department_with_tags)
      api_basic_authorize(subcollection_action_identifier(:groups, :tags, :assign))

      run_post("#{groups_url(group.id)}/tags", :action => "assign", :category => "department", :name => "finance")

      expected = {
        "results" => [
          a_hash_including(
            "success"      => true,
            "message"      => a_string_matching(/assigning tag/i),
            "tag_category" => "department",
            "tag_name"     => "finance"
          )
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "can unassign a tag from a group" do
      group = FactoryGirl.create(:miq_group)
      FactoryGirl.create(:classification_department_with_tags)
      Classification.classify(group, "department", "finance")
      api_basic_authorize(subcollection_action_identifier(:groups, :tags, :unassign))

      run_post("#{groups_url(group.id)}/tags", :action => "unassign", :category => "department", :name => "finance")

      expected = {
        "results" => [
          a_hash_including(
            "success"      => true,
            "message"      => a_string_matching(/unassigning tag/i),
            "tag_category" => "department",
            "tag_name"     => "finance"
          )
        ]
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end
