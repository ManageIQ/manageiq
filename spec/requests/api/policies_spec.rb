#
# REST API Request Tests - Policies and Policy Profiles
#
# Policy and Policy Profiles primary collections:
#   /api/policies
#   /api/policy_profiles
#
# Policy subcollection:
#   /api/vms/:id/policies
#   /api/providers/:id/policies
#   /api/hosts/:id/policies
#   /api/resource_pools/:id/policies
#   /api/clusters/:id/policies
#   /api/templates/:id/policies
#   /api/policy_profiles/:id/policies
#
# Policy Profiles subcollection:
#   /api/vms/:id/policy_profiles
#   /api/providers/:id/policy_profiles
#   /api/hosts/:id/policy_profiles
#   /api/resource_pools/:id/policy_profiles
#   /api/clusters/:id/policy_profiles
#   /api/templates/:id/policy_profiles
#
describe "Policies API" do
  let(:zone)        { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server)  { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)         { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)        { FactoryGirl.create(:host) }

  let(:p1)          { FactoryGirl.create(:miq_policy, :description => "Policy 1") }
  let(:p2)          { FactoryGirl.create(:miq_policy, :description => "Policy 2") }
  let(:p3)          { FactoryGirl.create(:miq_policy, :description => "Policy 3") }

  let(:ps1)         { FactoryGirl.create(:miq_policy_set, :description => "Policy Set 1") }
  let(:ps2)         { FactoryGirl.create(:miq_policy_set, :description => "Policy Set 2") }

  let(:p_guids)     { [p1.guid, p2.guid] }
  let(:p_all_guids) { [p1.guid, p2.guid, p3.guid] }

  before do
    # Creating:  policy_set_1 = [policy_1, policy_2]  and  policy_set_2 = [policy_3]
    ps1.add_member(p1)
    ps1.add_member(p2)

    ps2.add_member(p3)
  end

  def test_no_policy_query(object_policies_url)
    api_basic_authorize

    run_get object_policies_url

    expect_empty_query_result(:policies)
  end

  def test_no_policy_profile_query(object_policy_profiles_url)
    api_basic_authorize

    run_get object_policy_profiles_url

    expect_empty_query_result(:policy_profiles)
  end

  def test_single_policy_query(object, object_policies_url)
    api_basic_authorize

    object.add_policy(p1)
    object.add_policy(ps2)

    run_get object_policies_url, :expand => "resources"

    expect_query_result(:policies, 1)
    expect_result_resources_to_match_hash([{"name" => p1.name, "description" => p1.description, "guid" => p1.guid}])
  end

  def test_multiple_policy_query(object, object_policies_url)
    api_basic_authorize

    object.add_policy(p1)
    object.add_policy(p2)
    object.add_policy(ps2)

    run_get object_policies_url, :expand => "resources"

    expect_query_result(:policies, 2)
    expect_result_resources_to_include_data("resources", "guid" => p_guids)
  end

  def test_policy_profile_query(object, object_policy_profiles_url)
    api_basic_authorize

    object.add_policy(p1)
    object.add_policy(ps2)

    run_get object_policy_profiles_url, :expand => "resources"

    expect_query_result(:policy_profiles, 1)
    expect_result_resources_to_include_data("resources", "guid" => Array.wrap(ps2.guid))
  end

  context "Policy collection" do
    it "query invalid policy" do
      api_basic_authorize action_identifier(:policies, :read, :resource_actions, :get)

      run_get policies_url(999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "query policies" do
      api_basic_authorize collection_action_identifier(:policies, :read, :get)

      run_get policies_url

      expect_query_result(:policies, 3, 3)
      expect_result_resources_to_include_hrefs("resources",
                                               [policies_url(p1.id), policies_url(p2.id), policies_url(p3.id)])
    end

    it "query policies in expanded form" do
      api_basic_authorize collection_action_identifier(:policies, :read, :get)

      run_get policies_url, :expand => "resources"

      expect_query_result(:policies, 3, 3)
      expect_result_resources_to_include_data("resources", "guid" => p_all_guids)
    end
  end

  context "Policy Profile collection" do
    let(:policy_profile)     { ps1 }
    let(:policy_profile_url) { policy_profiles_url(policy_profile.id) }

    it "query invalid policy profile" do
      api_basic_authorize action_identifier(:policy_profiles, :read, :resource_actions, :get)

      run_get policy_profiles_url(999_999)

      expect(response).to have_http_status(:not_found)
    end

    it "query Policy Profiles" do
      api_basic_authorize collection_action_identifier(:policy_profiles, :read, :get)

      run_get policy_profiles_url

      expect_query_result(:policy_profiles, 2, 2)
      expect_result_resources_to_include_hrefs("resources",
                                               [policy_profiles_url(ps1.id), policy_profiles_url(ps2.id)])
    end

    it "query individual Policy Profile" do
      api_basic_authorize action_identifier(:policy_profiles, :read, :resource_actions, :get)

      run_get policy_profile_url

      expect_single_resource_query(
        "name" => policy_profile.name, "description" => policy_profile.description, "guid" => policy_profile.guid
      )
    end

    it "query Policy Profile policies subcollection" do
      api_basic_authorize

      run_get "#{policy_profile_url}/policies", :expand => "resources"

      expect_query_result(:policies, p_guids.count)
      expect_result_resources_to_include_data("resources", "guid" => p_guids)
    end

    it "query Policy Profile with expanded policies subcollection" do
      api_basic_authorize action_identifier(:policy_profiles, :read, :resource_actions, :get)

      run_get policy_profile_url, :expand => "policies"

      expect_single_resource_query(
        "name" => policy_profile.name, "description" => policy_profile.description, "guid" => policy_profile.guid
      )
      expect_result_resources_to_include_data("policies", "guid" => p_guids)
    end
  end

  context "Provider policies subcollection" do
    let(:provider) { ems }

    let(:provider_url)                 { providers_url(provider.id) }
    let(:provider_policies_url)        { "#{provider_url}/policies" }
    let(:provider_policy_profiles_url) { "#{provider_url}/policy_profiles" }

    it "query Provider policies with no policies defined" do
      test_no_policy_query(provider_policies_url)
    end

    it "query Provider policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(provider_policy_profiles_url)
    end

    it "query Provider policies with one policy defined" do
      test_single_policy_query(provider, provider_policies_url)
    end

    it "query Provider policies with multiple policies defined" do
      test_multiple_policy_query(provider, provider_policies_url)
    end

    it "query Provider policy profiles" do
      test_policy_profile_query(provider, provider_policy_profiles_url)
    end
  end

  context "Host policies subcollection" do
    let(:host_url)                  { hosts_url(host.id) }
    let(:host_policies_url)         { "#{host_url}/policies" }
    let(:host_policy_profiles_url)  { "#{host_url}/policy_profiles" }

    it "query Host policies with no policies defined" do
      test_no_policy_query(host_policies_url)
    end

    it "query Host policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(host_policy_profiles_url)
    end

    it "query Host policies with one policy defined" do
      test_single_policy_query(host, host_policies_url)
    end

    it "query Host policies with multiple policies defined" do
      test_multiple_policy_query(host, host_policies_url)
    end

    it "query Host policy profiles" do
      test_policy_profile_query(host, host_policy_profiles_url)
    end
  end

  context "Resource Pool policies subcollection" do
    let(:rp) { FactoryGirl.create(:resource_pool, :name => "Resource Pool 1") }

    let(:rp_url)                  { resource_pools_url(rp.id) }
    let(:rp_policies_url)         { "#{rp_url}/policies" }
    let(:rp_policy_profiles_url)  { "#{rp_url}/policy_profiles" }

    it "query Resource Pool policies with no policies defined" do
      test_no_policy_query(rp_policies_url)
    end

    it "query Resource Pool policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(rp_policy_profiles_url)
    end

    it "query Resource Pool policies with one policy defined" do
      test_single_policy_query(rp, rp_policies_url)
    end

    it "query Resource Pool policies with multiple policies defined" do
      test_multiple_policy_query(rp, rp_policies_url)
    end

    it "query Resource Pool policy profiles" do
      test_policy_profile_query(rp, rp_policy_profiles_url)
    end
  end

  context "Cluster policies subcollection" do
    let(:cluster) do
      FactoryGirl.create(:ems_cluster,
                         :name => "Cluster 1", :ext_management_system => ems, :hosts => [host], :vms => [])
    end

    let(:cluster_url)                 { clusters_url(cluster.id) }
    let(:cluster_policies_url)        { "#{cluster_url}/policies" }
    let(:cluster_policy_profiles_url) { "#{cluster_url}/policy_profiles" }

    it "query Cluster policies with no policies defined" do
      test_no_policy_query(cluster_policies_url)
    end

    it "query Cluster policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(cluster_policy_profiles_url)
    end

    it "query Cluster policies with one policy defined" do
      test_single_policy_query(cluster, cluster_policies_url)
    end

    it "query Cluster policies with multiple policies defined" do
      test_multiple_policy_query(cluster, cluster_policies_url)
    end

    it "query Cluster policy profiles" do
      test_policy_profile_query(cluster, cluster_policy_profiles_url)
    end
  end

  context "Vms policies subcollection" do
    let(:vm)  { FactoryGirl.create(:vm) }

    let(:vm_url)                  { vms_url(vm.id) }
    let(:vm_policies_url)         { "#{vm_url}/policies" }
    let(:vm_policy_profiles_url)  { "#{vm_url}/policy_profiles" }

    it "query Vm policies with no policies defined" do
      test_no_policy_query(vm_policies_url)
    end

    it "query Vm policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(vm_policy_profiles_url)
    end

    it "query Vm policies with one policy defined" do
      test_single_policy_query(vm, vm_policies_url)
    end

    it "query Vm policies with multiple policies defined" do
      test_multiple_policy_query(vm, vm_policies_url)
    end

    it "query Vm policy profiles" do
      test_policy_profile_query(vm, vm_policy_profiles_url)
    end
  end

  context "Template policies subcollection" do
    let(:template)  do
      FactoryGirl.create(:miq_template,
                         :name => "Template 1", :vendor => "vmware", :location => "template_1.vmtx")
    end

    let(:template_url)                  { templates_url(template.id) }
    let(:template_policies_url)         { "#{template_url}/policies" }
    let(:template_policy_profiles_url)  { "#{template_url}/policy_profiles" }

    it "query Template policies with no policies defined" do
      test_no_policy_query(template_policies_url)
    end

    it "query Template policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(template_policy_profiles_url)
    end

    it "query Template policies with one policy defined" do
      test_single_policy_query(template, template_policies_url)
    end

    it "query Template policies with multiple policies defined" do
      test_multiple_policy_query(template, template_policies_url)
    end

    it "query Template policy profile" do
      test_policy_profile_query(template, template_policy_profiles_url)
    end
  end

  context "Policy CRUD actions" do
    let(:action) { FactoryGirl.create(:miq_action) }
    let(:conditions) { FactoryGirl.create_list(:condition, 2) }
    let(:event) { FactoryGirl.create(:miq_event_definition) }
    let(:miq_policy) { FactoryGirl.create(:miq_policy) }
    let(:miq_policy_contents) do
      {"policy_contents" => [{'event_id' => event.id,
                              "actions"  => [{"action_id" => action.id, "opts" => { :qualifier => "failure" }}] }]}
    end
    let(:sample_policy) do
      {
        "description"    => "sample policy",
        "name"           => "sample policy",
        "mode"           => "compliance",
        "towhat"         => "ManageIQ::Providers::Redhat::InfraManager",
        "conditions_ids" => [conditions.first.id, conditions.second.id],
      }
    end

    it "creates new policy" do
      api_basic_authorize collection_action_identifier(:policies, :create)
      run_post(policies_url, sample_policy.merge!(miq_policy_contents))
      policy = MiqPolicy.find(response.parsed_body["results"].first["id"])
      expect(response.parsed_body["results"].first["name"]).to eq("sample policy")
      expect(response.parsed_body["results"].first["towhat"]).to eq("ManageIQ::Providers::Redhat::InfraManager")
      expect(policy).to be_truthy
      expect(policy.conditions.count).to eq(2)
      expect(policy.actions.count).to eq(1)
      expect(policy.events.count).to eq(1)
      expect(response).to have_http_status(:ok)
    end

    it "shouldn't creates new policy with missing params" do
      api_basic_authorize collection_action_identifier(:policies, :create)
      run_post(policies_url, sample_policy)
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]["message"]).to include(miq_policy_contents.keys.join(", "))
    end

    it "deletes policy" do
      api_basic_authorize collection_action_identifier(:policies, :delete)
      run_post(policies_url, gen_request(:delete, "href" => policies_url(miq_policy.id)))
      policy_id = response.parsed_body["results"].first["id"]
      expect(MiqPolicy.exists?(policy_id)).to be_falsey
      expect(response).to have_http_status(:ok)
    end

    it "edits policy actions events and conditions" do
      api_basic_authorize collection_action_identifier(:policies, :edit)
      miq_policy.conditions << conditions
      expect(miq_policy.conditions.count).to eq(2)
      expect(miq_policy.actions.count).to eq(0)
      expect(miq_policy.events.count).to eq(0)
      run_post(policies_url(miq_policy.id), gen_request(:edit, miq_policy_contents.merge('conditions_ids' => [])))
      policy = MiqPolicy.find(response.parsed_body["id"])
      expect(response).to have_http_status(:ok)
      expect(policy.actions.count).to eq(1)
      expect(policy.events.count).to eq(1)
      expect(miq_policy.conditions.count).to eq(0)
    end
  end
end
