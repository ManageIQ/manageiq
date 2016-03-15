#
# Rest API Request Tests - Roles specs
#
# - Query all available features          /api/roles/:id/?expand=features       GET
# - Creating a role                       /api/roles                            POST
# - Creating a role via action            /api/roles                            action "create"
# - Creating multiple roles               /api/roles                            action "create"
# - Edit a role                           /api/roles/:id                        action "edit"
# - Edit multiple roles                   /api/roles                            action "edit"
# - Assign a single feature               /api/roles/:id/features               POST, action "assign"
# - Assign multiple features              /api/roles/:id/features               POST, action "assign"
# - Un-assign a single feature            /api/roles/:id/features               POST, action "unassign"
# - Un-assign multiple features           /api/roles/:id/features               POST, action "unassign"
# - Delete a role                         /api/roles/:id                        DELETE
# - Delete a role by action               /api/roles/:id                        action "delete"
# - Delete multiple roles                 /api/roles                            action "delete"
#
describe ApiController do
  let(:feature_identifiers) do
    %w(vm_explorer ems_infra_tag my_settings_time_profiles
       miq_request_view miq_report_run storage_manager_show_list)
  end
  let(:expected_attributes) { %w(id name read_only settings) }
  let(:sample_role1) do
    {
      "name"     => "sample_role_1",
      "settings" => {"restrictions" => {"vms" => "user"}},
      "features" => [
        {:identifier => "vm_explorer"},
        {:identifier => "ems_infra_tag"},
        {:identifier => "my_settings_time_profiles"}
      ]
    }
  end
  let(:sample_role2) do
    {
      "name"     => "sample_role_2",
      "settings" => {"restrictions" => {"vms" => "user_or_group"}},
      "features" => [
        {:identifier => "miq_request_view"},
        {:identifier => "miq_report_run"},
        {:identifier => "storage_manager_show_list"}
      ]
    }
  end
  let(:features_list) do
    {
      "features"  => [
        {:identifier => "miq_request_view"},
        {:identifier => "miq_report_run"},
        {:identifier => "storage_manager_show_list"}
      ]
    }
  end

  before(:each) do
    @product_features = feature_identifiers.collect do |identifier|
      FactoryGirl.create(:miq_product_feature, :identifier => identifier)
    end
  end

  def test_features_query(role, role_url, klass, attr = :id)
    api_basic_authorize

    run_get role_url, :expand => "features"
    expect_request_success

    expect(response_hash).to have_key("name")
    expect(response_hash["name"]).to eq(role.name)
    expect(response_hash).to have_key("features")
    expect(response_hash["features"].size).to eq(fetch_value(role.miq_product_features.count))

    expect_result_resources_to_include_data("features", attr.to_s => klass.pluck(attr))
  end

  describe "Features" do
    it "query available features" do
      role = FactoryGirl.create(:miq_user_role,
                                :name                 => "Test Role",
                                :miq_product_features => @product_features)
      test_features_query(role, roles_url(role.id), MiqProductFeature, :identifier)
    end
  end

  describe "Roles create" do
    it "rejects creation without appropriate role" do
      api_basic_authorize

      run_post(roles_url, sample_role1)

      expect_request_forbidden
    end

    it "rejects role creation with id specified" do
      api_basic_authorize collection_action_identifier(:roles, :create)

      run_post(roles_url, "name" => "sample role", "id" => 100)

      expect_bad_request(/id or href should not be specified/i)
    end

    it "supports single role creation" do
      api_basic_authorize collection_action_identifier(:roles, :create)

      run_post(roles_url, sample_role1)

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)

      role_id = response_hash["results"].first["id"]

      run_get "#{roles_url}/#{role_id}/", :expand => "features"

      expect(MiqUserRole.exists?(role_id)).to be_truthy
      role = MiqUserRole.find(role_id)

      sample_role1['features'].each do |feature|
        expect(role.allows?(feature)).to be_truthy
      end
    end

    it "supports single role creation via action" do
      api_basic_authorize collection_action_identifier(:roles, :create)

      run_post(roles_url, gen_request(:create, sample_role1))

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)

      role_id = response_hash["results"].first["id"]
      expect(MiqUserRole.exists?(role_id)).to be_truthy
      role = MiqUserRole.find(role_id)
      sample_role1['features'].each do |feature|
        expect(role.allows?(feature)).to be_truthy
      end
    end

    it "supports multiple role creation" do
      api_basic_authorize collection_action_identifier(:roles, :create)

      run_post(roles_url, gen_request(:create, [sample_role1, sample_role2]))

      expect_request_success
      expect_result_resources_to_include_keys("results", expected_attributes)

      results = response_hash["results"]
      r1_id = results.first["id"]
      r2_id = results.second["id"]
      expect(MiqUserRole.exists?(r1_id)).to be_truthy
      expect(MiqUserRole.exists?(r2_id)).to be_truthy

      role1 = MiqUserRole.find(r1_id)
      role2 = MiqUserRole.find(r2_id)

      sample_role1['features'].each do |feature|
        expect(role1.allows?(feature)).to be_truthy
      end
      sample_role2['features'].each do |feature|
        expect(role2.allows?(feature)).to be_truthy
      end
    end
  end

  describe "Roles edit" do
    it "rejects role edits without appropriate role" do
      role = FactoryGirl.create(:miq_user_role)
      api_basic_authorize
      run_post(roles_url, gen_request(:edit, "name" => "role name", "href" => roles_url(role.id)))

      expect_request_forbidden
    end

    it "rejects role edits for invalid resources" do
      api_basic_authorize collection_action_identifier(:roles, :edit)

      run_post(roles_url(999_999), gen_request(:edit, "name" => "updated role name"))

      expect_resource_not_found
    end

    it "supports single role edit" do
      api_basic_authorize collection_action_identifier(:roles, :edit)

      role = FactoryGirl.create(:miq_user_role)

      run_post(roles_url(role.id), gen_request(:edit, "name"     => "updated role",
                                                      "settings" => {"restrictions"  => {"vms" => "user_or_group"}}))

      expect_single_resource_query("id"       => role.id,
                                   "name"     => "updated role",
                                   "settings" => {"restrictions" => {"vms" => "user_or_group"}})
      expect(role.reload.name).to eq("updated role")
      expect(role.settings[:restrictions][:vms]).to eq(:user_or_group)
    end

    it "supports multiple role edits" do
      api_basic_authorize collection_action_identifier(:roles, :edit)

      r1 = FactoryGirl.create(:miq_user_role, :name => "role1")
      r2 = FactoryGirl.create(:miq_user_role, :name => "role2")

      run_post(roles_url, gen_request(:edit,
                                      [{"href" => roles_url(r1.id), "name" => "updated role1"},
                                       {"href" => roles_url(r2.id), "name" => "updated role2"}]))

      expect_results_to_match_hash("results",
                                   [{"id" => r1.id, "name" => "updated role1"},
                                    {"id" => r2.id, "name" => "updated role2"}])

      expect(r1.reload.name).to eq("updated role1")
      expect(r2.reload.name).to eq("updated role2")
    end
  end

  describe "Role Feature Assignments" do
    it "supports assigning just a single product feature" do
      api_basic_authorize collection_action_identifier(:roles, :edit)
      role = FactoryGirl.create(:miq_user_role, :features => "miq_request_approval")

      new_feature = {:identifier => "miq_request_view"}
      url = "#{roles_url}/#{role.id}/features"
      run_post(url, gen_request(:assign, new_feature))

      expect_request_success
      expect_result_resources_to_include_keys("results", %w(id name read_only))

      # Refresh the role object
      role = MiqUserRole.find(role.id)

      # Confirm original feature
      expect(role.allows?(:identifier => 'miq_request_approval')).to be_truthy

      # Confirm new feature
      expect(role.allows?(new_feature)).to be_truthy
    end

    it "supports assigning multiple product features" do
      api_basic_authorize collection_action_identifier(:roles, :edit)
      role = FactoryGirl.create(:miq_user_role, :features => "miq_request_approval")

      url = "#{roles_url}/#{role.id}/features"
      run_post(url, gen_request(:assign, features_list))

      expect_request_success
      expect_result_resources_to_include_keys("results", %w(id name read_only))

      # Refresh the role object
      role = MiqUserRole.find(role.id)

      # Confirm original feature
      expect(role.allows?(:identifier => 'miq_request_approval')).to be_truthy

      # Confirm new features
      features_list['features'].each do |feature|
        expect(role.allows?(feature)).to be_truthy
      end
    end

    it "supports un-assigning just a single product feature" do
      api_basic_authorize collection_action_identifier(:roles, :edit)
      role = FactoryGirl.create(:miq_user_role, :miq_product_features => @product_features)

      removed_feature = {:identifier => "ems_infra_tag"}
      url = "#{roles_url}/#{role.id}/features"
      run_post(url, gen_request(:unassign, removed_feature))

      expect_request_success
      # Confirm that we've only removed ems_infra_tag
      expect_result_resources_to_include_keys("results", %w(id name read_only))

      # Refresh the role object
      role = MiqUserRole.find(role.id)

      @product_features.each do |feature|
        expect(role.allows?(feature)).to be_truthy unless feature[:identifier].eql?('ems_infra_tag')
        expect(role.allows?(feature)).to be_falsey if feature[:identifier].eql?('ems_infra_tag')
      end
    end

    it "supports un-assigning multiple product features" do
      api_basic_authorize collection_action_identifier(:roles, :edit)
      role = FactoryGirl.create(:miq_user_role, :miq_product_features => @product_features)

      url = "#{roles_url}/#{role.id}/features"
      run_post(url, gen_request(:unassign, features_list))

      expect_request_success
      expect_result_resources_to_include_keys("results", %w(id name read_only))

      # Refresh the role object
      role = MiqUserRole.find(role.id)

      # Confirm requested features removed first, and others remain
      @product_features.each do |feature|
        expect(role.allows?(feature)).to be_truthy unless features_list['features'].find do |removed_feature|
          removed_feature[:identifier] == feature[:identifier]
        end
        expect(role.allows?(feature)).to be_falsey if features_list['features'].find do |removed_feature|
          removed_feature[:identifier] == feature[:identifier]
        end
      end
    end
  end

  describe "Roles delete" do
    it "rejects role deletion, by post action, without appropriate role" do
      api_basic_authorize

      run_post(roles_url, gen_request(:delete, "name" => "role name", "href" => roles_url(100)))

      expect_request_forbidden
    end

    it "rejects role deletion without appropriate role" do
      api_basic_authorize

      run_delete(roles_url(100))

      expect_request_forbidden
    end

    it "rejects role deletes for invalid roles" do
      api_basic_authorize collection_action_identifier(:roles, :delete)

      run_delete(roles_url(999_999))

      expect_resource_not_found
    end

    it "supports single role delete" do
      api_basic_authorize collection_action_identifier(:roles, :delete)

      role = FactoryGirl.create(:miq_user_role, :name => "role1")

      run_delete(roles_url(role.id))

      expect_request_success_with_no_content
      expect(MiqUserRole.exists?(role.id)).to be_falsey
    end

    it "supports single role delete action" do
      api_basic_authorize collection_action_identifier(:roles, :delete)

      role = FactoryGirl.create(:miq_user_role, :name => "role1")

      run_post(roles_url(role.id), gen_request(:delete))

      expect_request_success
      expect(MiqUserRole.exists?(role.id)).to be_falsey
    end

    it "supports multiple role deletes" do
      api_basic_authorize collection_action_identifier(:roles, :delete)

      r1 = FactoryGirl.create(:miq_user_role, :name => "role name 1")
      r2 = FactoryGirl.create(:miq_user_role, :name => "role name 2")

      run_post(roles_url, gen_request(:delete,
                                      [{"href" => roles_url(r1.id)},
                                       {"href" => roles_url(r2.id)}]))

      expect_request_success
      expect(MiqUserRole.exists?(r1.id)).to be_falsey
      expect(MiqUserRole.exists?(r2.id)).to be_falsey
    end
  end
end
