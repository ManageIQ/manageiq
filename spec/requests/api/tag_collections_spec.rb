#
# REST API Request Tests - Tags subcollection specs for Non-Vm collections
#
describe "Tag Collections API" do
  let(:zone)         { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server)   { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)          { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)         { FactoryGirl.create(:host) }

  let(:tag1)         { {:category => "department", :name => "finance", :path => "/managed/department/finance"} }
  let(:tag2)         { {:category => "cc",         :name => "001",     :path => "/managed/cc/001"} }
  let(:tag_paths)    { [tag1[:path], tag2[:path]] }

  def classify_resource(resource)
    Classification.classify(resource, tag1[:category], tag1[:name])
    Classification.classify(resource, tag2[:category], tag2[:name])
  end

  def tag1_results(resource_href)
    [{:success => true, :href => resource_href, :tag_category => tag1[:category], :tag_name => tag1[:name]}]
  end

  def expect_resource_has_tags(resource, tag_names)
    tag_names = Array.wrap(tag_names)
    expect(resource.tags.count).to eq(tag_names.count)
    expect(resource.tags.map(&:name).sort).to eq(tag_names.sort)
  end

  before do
    FactoryGirl.create(:classification_department_with_tags)
    FactoryGirl.create(:classification_cost_center_with_tags)
  end

  context "Provider Tag subcollection" do
    let(:provider)          { ems }
    let(:provider_url)      { providers_url(provider.id) }
    let(:provider_tags_url) { "#{provider_url}/tags" }

    it "query all tags of a Provider and verify tag category and names" do
      api_basic_authorize
      classify_resource(provider)

      run_get provider_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, Tag.count)
      expect_result_resources_to_include_data("resources", "name" => tag_paths)
    end

    it "does not assign a tag to a Provider without appropriate role" do
      api_basic_authorize

      run_post(provider_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "assigns a tag to a Provider" do
      api_basic_authorize subcollection_action_identifier(:providers, :tags, :assign)

      run_post(provider_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(provider_url))
    end

    it "does not unassign a tag from a Provider without appropriate role" do
      api_basic_authorize

      run_post(provider_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "unassigns a tag from a Provider" do
      api_basic_authorize subcollection_action_identifier(:providers, :tags, :unassign)
      classify_resource(provider)

      run_post(provider_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(provider_url))
      expect_resource_has_tags(provider, tag2[:path])
    end
  end

  context "Host Tag subcollection" do
    let(:host_url)      { hosts_url(host.id) }
    let(:host_tags_url) { "#{host_url}/tags" }

    it "query all tags of a Host and verify tag category and names" do
      api_basic_authorize
      classify_resource(host)

      run_get host_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, Tag.count)
      expect_result_resources_to_include_data("resources", "name" => tag_paths)
    end

    it "does not assign a tag to a Host without appropriate role" do
      api_basic_authorize

      run_post(host_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "assigns a tag to a Host" do
      api_basic_authorize subcollection_action_identifier(:hosts, :tags, :assign)

      run_post(host_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(host_url))
    end

    it "does not unassign a tag from a Host without appropriate role" do
      api_basic_authorize

      run_post(host_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "unassigns a tag from a Host" do
      api_basic_authorize subcollection_action_identifier(:hosts, :tags, :unassign)
      classify_resource(host)

      run_post(host_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(host_url))
      expect_resource_has_tags(host, tag2[:path])
    end
  end

  context "Data Store Tag subcollection" do
    let(:ds)          { FactoryGirl.create(:storage, :name => "Storage 1", :store_type => "VMFS") }
    let(:ds_url)      { data_stores_url(ds.id) }
    let(:ds_tags_url) { "#{ds_url}/tags" }

    it "query all tags of a Data Store and verify tag category and names" do
      api_basic_authorize
      classify_resource(ds)

      run_get ds_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, Tag.count)
      expect_result_resources_to_include_data("resources", "name" => tag_paths)
    end

    it "does not assign a tag to a Data Store without appropriate role" do
      api_basic_authorize

      run_post(ds_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "assigns a tag to a Data Store" do
      api_basic_authorize subcollection_action_identifier(:data_stores, :tags, :assign)

      run_post(ds_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(ds_url))
    end

    it "does not unassign a tag from a Data Store without appropriate role" do
      api_basic_authorize

      run_post(ds_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "unassigns a tag from a Data Store" do
      api_basic_authorize subcollection_action_identifier(:data_stores, :tags, :unassign)
      classify_resource(ds)

      run_post(ds_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(ds_url))
      expect_resource_has_tags(ds, tag2[:path])
    end
  end

  context "Resource Pool Tag subcollection" do
    let(:rp)          { FactoryGirl.create(:resource_pool, :name => "Resource Pool 1") }
    let(:rp_url)      { resource_pools_url(rp.id) }
    let(:rp_tags_url) { "#{rp_url}/tags" }

    it "query all tags of a Resource Pool and verify tag category and names" do
      api_basic_authorize
      classify_resource(rp)

      run_get rp_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, Tag.count)
      expect_result_resources_to_include_data("resources", "name" => tag_paths)
    end

    it "does not assign a tag to a Resource Pool without appropriate role" do
      api_basic_authorize

      run_post(rp_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "assigns a tag to a Resource Pool" do
      api_basic_authorize subcollection_action_identifier(:resource_pools, :tags, :assign)

      run_post(rp_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(rp_url))
    end

    it "does not unassign a tag from a Resource Pool without appropriate role" do
      api_basic_authorize

      run_post(rp_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "unassigns a tag from a Resource Pool" do
      api_basic_authorize subcollection_action_identifier(:resource_pools, :tags, :unassign)
      classify_resource(rp)

      run_post(rp_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(rp_url))
      expect_resource_has_tags(rp, tag2[:path])
    end
  end

  context "Cluster Tag subcollection" do
    let(:cluster) do
      FactoryGirl.create(:ems_cluster,
                         :name                  => "cluster 1",
                         :ext_management_system => ems,
                         :hosts                 => [host],
                         :vms                   => [])
    end

    let(:cluster_url)      { clusters_url(cluster.id) }
    let(:cluster_tags_url) { "#{cluster_url}/tags" }

    it "query all tags of a Cluster and verify tag category and names" do
      api_basic_authorize
      classify_resource(cluster)

      run_get cluster_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, Tag.count)
      expect_result_resources_to_include_data("resources", "name" => tag_paths)
    end

    it "does not assign a tag to a Cluster without appropriate role" do
      api_basic_authorize

      run_post(cluster_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "assigns a tag to a Cluster" do
      api_basic_authorize subcollection_action_identifier(:clusters, :tags, :assign)

      run_post(cluster_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(cluster_url))
    end

    it "does not unassign a tag from a Cluster without appropriate role" do
      api_basic_authorize

      run_post(cluster_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "unassigns a tag from a Cluster" do
      api_basic_authorize subcollection_action_identifier(:clusters, :tags, :unassign)
      classify_resource(cluster)

      run_post(cluster_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(cluster_url))
      expect_resource_has_tags(cluster, tag2[:path])
    end
  end

  context "Service Tag subcollection" do
    let(:service)          { FactoryGirl.create(:service) }
    let(:service_url)      { services_url(service.id) }
    let(:service_tags_url) { "#{service_url}/tags" }

    it "query all tags of a Service and verify tag category and names" do
      api_basic_authorize
      classify_resource(service)

      run_get service_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, Tag.count)
      expect_result_resources_to_include_data("resources", "name" => tag_paths)
    end

    it "does not assign a tag to a Service without appropriate role" do
      api_basic_authorize

      run_post(service_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "assigns a tag to a Service" do
      api_basic_authorize subcollection_action_identifier(:services, :tags, :assign)

      run_post(service_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(service_url))
    end

    it "does not unassign a tag from a Service without appropriate role" do
      api_basic_authorize

      run_post(service_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "unassigns a tag from a Service" do
      api_basic_authorize subcollection_action_identifier(:services, :tags, :unassign)
      classify_resource(service)

      run_post(service_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(service_url))
      expect_resource_has_tags(service, tag2[:path])
    end
  end

  context "Service Template Tag subcollection" do
    let(:service_template)          { FactoryGirl.create(:service_template) }
    let(:service_template_url)      { service_templates_url(service_template.id) }
    let(:service_template_tags_url) { "#{service_template_url}/tags" }

    it "query all tags of a Service Template and verify tag category and names" do
      api_basic_authorize
      classify_resource(service_template)

      run_get service_template_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, Tag.count)
      expect_result_resources_to_include_data("resources", "name" => tag_paths)
    end

    it "does not assign a tag to a Service Template without appropriate role" do
      api_basic_authorize

      run_post(service_template_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "assigns a tag to a Service Template" do
      api_basic_authorize subcollection_action_identifier(:service_templates, :tags, :assign)

      run_post(service_template_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(service_template_url))
    end

    it "does not unassign a tag from a Service Template without appropriate role" do
      api_basic_authorize

      run_post(service_template_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "unassigns a tag from a Service Template" do
      api_basic_authorize subcollection_action_identifier(:service_templates, :tags, :unassign)
      classify_resource(service_template)

      run_post(service_template_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(service_template_url))
      expect_resource_has_tags(service_template, tag2[:path])
    end
  end

  context "Tenant Tag subcollection" do
    let(:tenant)          { FactoryGirl.create(:tenant, :name => "Tenant A", :description => "Tenant A Description") }
    let(:tenant_url)      { tenants_url(tenant.id) }
    let(:tenant_tags_url) { "#{tenant_url}/tags" }

    it "query all tags of a Tenant and verify tag category and names" do
      api_basic_authorize
      classify_resource(tenant)

      run_get tenant_tags_url, :expand => "resources"

      expect_query_result(:tags, 2, Tag.count)
      expect_result_resources_to_include_data("resources", "name" => tag_paths)
    end

    it "does not assign a tag to a Tenant without appropriate role" do
      api_basic_authorize

      run_post(tenant_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "assigns a tag to a Tenant" do
      api_basic_authorize subcollection_action_identifier(:tenants, :tags, :assign)

      run_post(tenant_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(tenant_url))
    end

    it "does not unassign a tag from a Tenant without appropriate role" do
      api_basic_authorize

      run_post(tenant_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect(response).to have_http_status(:forbidden)
    end

    it "unassigns a tag from a Tenant" do
      api_basic_authorize subcollection_action_identifier(:tenants, :tags, :unassign)
      classify_resource(tenant)

      run_post(tenant_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))

      expect_tagging_result(tag1_results(tenant_url))
      expect_resource_has_tags(tenant, tag2[:path])
    end
  end

  context "Blueprint Tag subcollection" do
    it "can list all the tags of a blueprint" do
      api_basic_authorize
      blueprint = FactoryGirl.create(:blueprint)

      run_get("#{blueprints_url(blueprint.id)}/tags")

      expect(response).to have_http_status(:ok)
    end

    it "can assign a tag to a blueprint with an appropriate role" do
      api_basic_authorize subcollection_action_identifier(:blueprints, :tags, :assign)
      blueprint = FactoryGirl.create(:blueprint)

      run_post("#{blueprints_url(blueprint.id)}/tags",
               :action   => "assign",
               :category => tag1[:category],
               :name     => tag1[:name])

      expect(response).to have_http_status(:ok)
    end

    it "can unassign a tag from a bluepring with an appropriate role" do
      api_basic_authorize subcollection_action_identifier(:blueprints, :tags, :unassign)
      blueprint = FactoryGirl.create(:blueprint)
      classify_resource(blueprint)

      run_post("#{blueprints_url(blueprint.id)}/tags",
               :action   => "unassign",
               :category => tag1[:category],
               :name     => tag1[:name])

      expect(response).to have_http_status(:ok)
    end

    it "will not assign tags to blueprints without an appropriate role" do
      api_basic_authorize
      blueprint = FactoryGirl.create(:blueprint)

      run_post("#{blueprints_url(blueprint.id)}/tags",
               :action   => "assign",
               :category => tag1[:category],
               :name     => tag1[:name])

      expect(response).to have_http_status(:forbidden)
    end

    it "will not unassign tags from blueprints without an approiate role" do
      api_basic_authorize
      blueprint = FactoryGirl.create(:blueprint)
      classify_resource(blueprint)

      run_post("#{blueprints_url(blueprint.id)}/tags",
               :action   => "unassign",
               :category => tag1[:category],
               :name     => tag1[:name])

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'Vm assign_tags action' do
    let(:bad_tag) { {:category => "cc", :name => "002"} }
    let(:vm1)                { FactoryGirl.create(:vm_vmware,    :host => host, :ems_id => ems.id) }
    let(:vm2)                { FactoryGirl.create(:vm_vmware,    :host => host, :ems_id => ems.id) }

    it 'can bulk assign tags to multiple vms' do
      api_basic_authorize collection_action_identifier(:vms, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'id' => vm1.id, 'tags' => [{ 'category' => tag1[:category], 'name' => tag1[:name] }] },
          { 'id' => vm2.id, 'tags' => [{ 'category' => tag2[:category], 'name' => tag2[:name] }] }
        ]
      }

      run_post(vms_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag2[:category],
                           'tag_name'     => tag2[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can bulk assign tags to multiple vms by href' do
      api_basic_authorize collection_action_identifier(:vms, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'href' => vms_url(vm1.id), 'tags' => [{ 'category' => tag1[:category], 'name' => tag1[:name] }] },
          { 'href' => vms_url(vm2.id), 'tags' => [{ 'category' => tag2[:category], 'name' => tag2[:name] }] }
        ]
      }

      run_post(vms_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag2[:category],
                           'tag_name'     => tag2[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'will return success and failure messages for each vm and tag' do
      api_basic_authorize collection_action_identifier(:vms, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'id' => 999_999, 'tags' => [{'category' => 'department', 'name' => 'finance'}] },
          { 'id' => vm2.id, 'tags' => [
            {'category' => bad_tag[:category], 'name' => bad_tag[:name]},
            {'category' => tag1[:category], 'name' => tag1[:name]}
          ]}
        ]
      }

      run_post(vms_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success' => false, 'message' => a_string_including("Couldn't find Vm")),
          a_hash_including('success'      => false,
                           'tag_category' => bad_tag[:category],
                           'tag_name'     => bad_tag[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'fails without an appropriate role' do
      api_basic_authorize

      run_post(vms_url, :action => 'assign_tags')

      expect(response).to have_http_status(:forbidden)
    end

    it 'can bulk assign tags by href' do
      api_basic_authorize collection_action_identifier(:vms, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'id' => vm1.id, 'tags' => [{'href' => tags_url(Tag.find_by(:name => tag1[:path]).id)}] },
          { 'id' => vm2.id, 'tags' => [{'href' => tags_url(Tag.find_by(:name => tag2[:path]).id)}] }
        ]
      }

      run_post(vms_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag2[:category],
                           'tag_name'     => tag2[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can bulk assign tags by id' do
      api_basic_authorize collection_action_identifier(:vms, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'id' => vm1.id, 'tags' => [{'id' => Tag.find_by(:name => tag1[:path]).id}] },
          { 'id' => vm2.id, 'tags' => [{'id' => Tag.find_by(:name => tag2[:path]).id}] }
        ]
      }

      run_post(vms_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag2[:category],
                           'tag_name'     => tag2[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end

  context 'Services assign_tags action' do
    let(:bad_tag) { {:category => "cc", :name => "002"} }
    let(:service1)                { FactoryGirl.create(:service) }
    let(:service2)                { FactoryGirl.create(:service) }

    it 'can bulk assign tags to multiple services' do
      api_basic_authorize collection_action_identifier(:services, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'id' => service1.id, 'tags' => [{ 'category' => tag1[:category], 'name' => tag1[:name] }] },
          { 'id' => service2.id, 'tags' => [{ 'category' => tag2[:category], 'name' => tag2[:name] }] }
        ]
      }

      run_post(services_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag2[:category],
                           'tag_name'     => tag2[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can bulk assign tags to multiple services by href' do
      api_basic_authorize collection_action_identifier(:services, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'href' => services_url(service1.id), 'tags' => [{ 'category' => tag1[:category], 'name' => tag1[:name] }] },
          { 'href' => services_url(service2.id), 'tags' => [{ 'category' => tag2[:category], 'name' => tag2[:name] }] }
        ]
      }

      run_post(services_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag2[:category],
                           'tag_name'     => tag2[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'will return success and failure messages for each service and tag' do
      api_basic_authorize collection_action_identifier(:services, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'id' => 999_999, 'tags' => [{'category' => 'department', 'name' => 'finance'}] },
          { 'id' => service2.id, 'tags' => [
            {'category' => bad_tag[:category], 'name' => bad_tag[:name]},
            {'category' => tag1[:category], 'name' => tag1[:name]}
          ]}
        ]
      }

      run_post(services_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success' => false, 'message' => a_string_including("Couldn't find Service")),
          a_hash_including('success'      => false,
                           'tag_category' => bad_tag[:category],
                           'tag_name'     => bad_tag[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'fails without an appropriate role' do
      api_basic_authorize

      run_post(services_url, :action => 'assign_tags')

      expect(response).to have_http_status(:forbidden)
    end

    it 'can bulk assign tags by href' do
      api_basic_authorize collection_action_identifier(:services, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'id' => service1.id, 'tags' => [{'href' => tags_url(Tag.find_by(:name => tag1[:path]).id)}] },
          { 'id' => service2.id, 'tags' => [{'href' => tags_url(Tag.find_by(:name => tag2[:path]).id)}] }
        ]
      }

      run_post(services_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag2[:category],
                           'tag_name'     => tag2[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can bulk assign tags by id' do
      api_basic_authorize collection_action_identifier(:services, :assign_tags)
      request_body = {
        'action'    => 'assign_tags',
        'resources' => [
          { 'id' => service1.id, 'tags' => [{'id' => Tag.find_by(:name => tag1[:path]).id}] },
          { 'id' => service2.id, 'tags' => [{'id' => Tag.find_by(:name => tag2[:path]).id}] }
        ]
      }

      run_post(services_url, request_body)

      expected = {
        'results' => [
          a_hash_including('success'      => true,
                           'tag_category' => tag1[:category],
                           'tag_name'     => tag1[:name]),
          a_hash_including('success'      => true,
                           'tag_category' => tag2[:category],
                           'tag_name'     => tag2[:name])
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end
  end
end
