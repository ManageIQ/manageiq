#
# Rest API Collections Tests
#
describe "Rest API Collections" do
  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :zone => zone) }
  let(:ems) { FactoryGirl.create(:ext_management_system) }
  let(:template) do
    FactoryGirl.create(:miq_template, :name => "template 1", :vendor => "vmware", :location => "template1.vmtx")
  end

  def test_collection_query(collection, collection_url, klass, attr = :id)
    run_get collection_url, :expand => "resources"

    expect_query_result(collection, klass.count, klass.count)
    expect_result_resources_to_include_data("resources", attr.to_s => klass.pluck(attr))
  end

  def test_collection_bulk_query(collection, collection_url, klass, id = nil)
    obj = id.nil? ? klass.first : klass.find(id)
    url = send("#{collection}_url", obj.id)
    attr_list = String(Api::ApiConfig.collections[collection].identifying_attrs).split(",")
    attr_list |= %w(guid) if klass.attribute_method?(:guid)
    resources = [{"id" => obj.id}, {"href" => url}]
    attr_list.each { |attr| resources << {attr => obj.public_send(attr)} }

    run_post(collection_url, gen_request(:query, resources))

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["results"].size).to eq(resources.size)
    expect(response.parsed_body).to include(
      "results" => all(
        a_hash_including("id" => obj.id, "href" => a_string_matching(url))
      )
    )
  end

  context "Collections" do
    it "query Automate Domains" do
      api_basic_authorize("miq_ae_domain_view")
      FactoryGirl.create(:miq_ae_domain)
      test_collection_query(:automate_domains, automate_domains_url, MiqAeDomain)
    end

    it "query Automation Requests" do
      api_basic_authorize
      FactoryGirl.create(:automation_request)
      test_collection_query(:automation_requests, automation_requests_url, AutomationRequest)
    end

    it "query Availability Zones" do
      api_basic_authorize("availability_zone_show_list")
      FactoryGirl.create(:availability_zone)
      test_collection_query(:availability_zones, availability_zones_url, AvailabilityZone)
    end

    it "query Categories" do
      api_basic_authorize("ops_settings")
      FactoryGirl.create(:category)
      test_collection_query(:categories, categories_url, Category)
    end

    it "query Chargebacks" do
      api_basic_authorize("chargeback")
      FactoryGirl.create(:chargeback_rate)
      test_collection_query(:chargebacks, chargebacks_url, ChargebackRate)
    end

    it "query Currencies" do
      api_basic_authorize
      FactoryGirl.create(:chargeback_rate_detail_currency)
      test_collection_query(:currencies, "/api/currencies", ChargebackRateDetailCurrency)
    end

    it "query Measures" do
      api_basic_authorize
      FactoryGirl.create(:chargeback_rate_detail_measure)
      test_collection_query(:measures, "/api/measures", ChargebackRateDetailMeasure)
    end

    it "query Clusters" do
      api_basic_authorize("ems_cluster_show_list")
      FactoryGirl.create(:ems_cluster)
      test_collection_query(:clusters, clusters_url, EmsCluster)
    end

    it "query Conditions" do
      api_basic_authorize("condition")
      FactoryGirl.create(:condition)
      test_collection_query(:conditions, conditions_url, Condition)
    end

    it "query Actions" do
      api_basic_authorize("action_show_list")
      FactoryGirl.create(:miq_action)
      test_collection_query(:actions, actions_url, MiqAction)
    end

    it "query Data Stores" do
      api_basic_authorize("storage_show_list")
      FactoryGirl.create(:storage)
      test_collection_query(:data_stores, data_stores_url, Storage)
    end

    it "query Events" do
      api_basic_authorize("event")
      FactoryGirl.create(:miq_event_definition)
      test_collection_query(:events, events_url, MiqEventDefinition)
    end

    it "query Features" do
      api_basic_authorize
      FactoryGirl.create(:miq_product_feature, :identifier => "vm_auditing")
      test_collection_query(:features, features_url, MiqProductFeature)
    end

    it "query Flavors" do
      api_basic_authorize("flavor_show_list")
      FactoryGirl.create(:flavor)
      test_collection_query(:flavors, flavors_url, Flavor)
    end

    it "query Groups" do
      expect(Tenant.exists?).to be_truthy
      FactoryGirl.create(:miq_group)
      api_basic_authorize "rbac_group_show_list"
      run_get groups_url, :expand => 'resources'
      expect_query_result(:groups, MiqGroup.non_tenant_groups.count, MiqGroup.count)
      expect_result_resources_to_include_data('resources', 'id' => MiqGroup.non_tenant_groups.pluck(:id))
    end

    it "query Hosts" do
      api_basic_authorize("host_show_list")
      FactoryGirl.create(:host)
      test_collection_query(:hosts, hosts_url, Host, :guid)
    end

    it "query Pictures" do
      api_basic_authorize
      FactoryGirl.create(:picture)
      test_collection_query(:pictures, pictures_url, Picture)
    end

    it "query Policies" do
      api_basic_authorize("policy_view")
      FactoryGirl.create(:miq_policy)
      test_collection_query(:policies, policies_url, MiqPolicy)
    end

    it "query Policy Actions" do
      api_basic_authorize("control_explorer_view")
      FactoryGirl.create(:miq_action)
      test_collection_query(:policy_actions, policy_actions_url, MiqAction)
    end

    it "query Policy Profiles" do
      api_basic_authorize("policy_profile_view")
      FactoryGirl.create(:miq_policy_set)
      test_collection_query(:policy_profiles, policy_profiles_url, MiqPolicySet)
    end

    it "query Providers" do
      api_basic_authorize("ems_infra_show_list")
      FactoryGirl.create(:ext_management_system)
      test_collection_query(:providers, providers_url, ExtManagementSystem, :guid)
    end

    it "query Provision Dialogs" do
      api_basic_authorize("miq_ae_customization_explorer")
      FactoryGirl.create(:miq_dialog)
      test_collection_query(:provision_dialogs, provision_dialogs_url, MiqDialog)
    end

    it "query Provision Requests" do
      api_basic_authorize("miq_request_show_list")
      FactoryGirl.create(:miq_provision_request, :source => template, :requester => @user)
      test_collection_query(:provision_requests, provision_requests_url, MiqProvisionRequest)
    end

    it "query Rates" do
      api_basic_authorize("chargeback_rates")
      FactoryGirl.build(:chargeback_rate_detail)
      test_collection_query(:rates, rates_url, ChargebackRateDetail)
    end

    it "query Reports" do
      api_basic_authorize("miq_report_saved_reports_view")
      FactoryGirl.create(:miq_report)
      test_collection_query(:reports, reports_url, MiqReport)
    end

    it "query Report Results" do
      api_basic_authorize("miq_report_view")
      FactoryGirl.create(:miq_report_result)
      test_collection_query(:results, results_url, MiqReportResult)
    end

    it "query Request Tasks" do
      api_basic_authorize
      FactoryGirl.create(:miq_request_task)
      test_collection_query(:request_tasks, request_tasks_url, MiqRequestTask)
    end

    it "query Requests" do
      api_basic_authorize("miq_request_show_list")
      FactoryGirl.create(:vm_migrate_request, :requester => @user)
      test_collection_query(:requests, requests_url, MiqRequest)
    end

    it "query Resource Pools" do
      api_basic_authorize("resource_pool_show_list")
      FactoryGirl.create(:resource_pool)
      test_collection_query(:resource_pools, resource_pools_url, ResourcePool)
    end

    it "query Roles" do
      api_basic_authorize("rbac_role_show_list")
      FactoryGirl.create(:miq_user_role)
      test_collection_query(:roles, roles_url, MiqUserRole)
    end

    it "query Security Groups" do
      api_basic_authorize("security_group_show_list")
      FactoryGirl.create(:security_group)
      test_collection_query(:security_groups, security_groups_url, SecurityGroup)
    end

    it "query Servers" do
      api_basic_authorize
      miq_server # create resource
      test_collection_query(:servers, servers_url, MiqServer, :guid)
    end

    it "query Service Catalogs" do
      api_basic_authorize("svc_catalog_provision")
      FactoryGirl.create(:service_template_catalog)
      test_collection_query(:service_catalogs, service_catalogs_url, ServiceTemplateCatalog)
    end

    it "query Service Dialogs" do
      api_basic_authorize("miq_ae_customization_explorer")
      FactoryGirl.create(:dialog, :label => "ServiceDialog1")
      test_collection_query(:service_dialogs, service_dialogs_url, Dialog)
    end

    it "query Service Requests" do
      api_basic_authorize("miq_request_view")
      FactoryGirl.create(:service_template_provision_request, :requester => @user)
      test_collection_query(:service_requests, service_requests_url, ServiceTemplateProvisionRequest)
    end

    it "query Service Templates" do
      api_basic_authorize("svc_catalog_provision")
      FactoryGirl.create(:service_template)
      test_collection_query(:service_templates, service_templates_url, ServiceTemplate, :guid)
    end

    it "query Services" do
      api_basic_authorize("service_view")
      FactoryGirl.create(:service)
      test_collection_query(:services, services_url, Service)
    end

    it "query Tags" do
      api_basic_authorize("ops_settings")
      FactoryGirl.create(:classification_cost_center_with_tags)
      test_collection_query(:tags, tags_url, Tag)
    end

    it "query Tasks" do
      api_basic_authorize("tasks_view")
      FactoryGirl.create(:miq_task)
      test_collection_query(:tasks, tasks_url, MiqTask)
    end

    it "query Templates" do
      api_basic_authorize("miq_template_show_list")
      template # create resource
      test_collection_query(:templates, templates_url, MiqTemplate, :guid)
    end

    it "query Tenants" do
      api_basic_authorize "rbac_tenant_view"
      Tenant.seed
      test_collection_query(:tenants, tenants_url, Tenant)
    end

    it "query Users" do
      api_basic_authorize("rbac_user_show_list")
      FactoryGirl.create(:user)
      test_collection_query(:users, users_url, User)
    end

    it "query Vms" do
      api_basic_authorize("vm_show_list")
      FactoryGirl.create(:vm_vmware)
      test_collection_query(:vms, vms_url, Vm, :guid)
    end

    it "query Zones" do
      api_basic_authorize("zone")
      FactoryGirl.create(:zone, :name => "api zone")
      test_collection_query(:zones, zones_url, Zone)
    end

    it "query ContainerDeployments" do
      api_basic_authorize("container_deployment_show")
      FactoryGirl.create(:container_deployment)
      test_collection_query(:container_deployments, container_deployments_url, ContainerDeployment)
    end

    it 'queries ArbitrationProfiles' do
      api_basic_authorize("arbitration_profile_show_list")
      ems = FactoryGirl.create(:ext_management_system)
      FactoryGirl.create(:arbitration_profile, :ems_id => ems.id)
      test_collection_query(:arbitration_profiles, arbitration_profiles_url, ArbitrationProfile)
    end

    it 'queries CloudNetworks' do
      api_basic_authorize("miq_cloud_networks_view")
      FactoryGirl.create(:cloud_network)
      test_collection_query(:cloud_networks, cloud_networks_url, CloudNetwork)
    end

    it 'queries ArbitrationSettings' do
      api_basic_authorize("show_arbitration_setting")
      FactoryGirl.create(:arbitration_setting)
      test_collection_query(:arbitration_settings, arbitration_settings_url, ArbitrationSetting)
    end

    it 'queries ArbitrationRules' do
      api_basic_authorize("arbitration_rule_show_list")
      FactoryGirl.create(:arbitration_rule)
      test_collection_query(:arbitration_rules, arbitration_rules_url, ArbitrationRule)
    end

    it 'query LoadBalancers' do
      api_basic_authorize("load_balancer_show_list")
      FactoryGirl.create(:load_balancer)
      test_collection_query(:load_balancers, load_balancers_url, LoadBalancer)
    end

    it 'query Alerts' do
      api_basic_authorize("alert_status_show_list")
      FactoryGirl.create(:miq_alert_status)
      test_collection_query(:alerts, alerts_url, MiqAlertStatus)
    end
  end

  context "Collections Bulk Queries" do
    it 'bulk query MiqAeDomain' do
      api_basic_authorize("miq_ae_domain_view")
      FactoryGirl.create(:miq_ae_domain)
      test_collection_bulk_query(:automate_domains, automate_domains_url, MiqAeDomain)
    end

    it 'bulk query ArbitrationProfiles' do
      api_basic_authorize("arbitration_profile_show_list")
      ems = FactoryGirl.create(:ext_management_system)
      FactoryGirl.create(:arbitration_profile, :ems_id => ems.id)
      test_collection_bulk_query(:arbitration_profiles, arbitration_profiles_url, ArbitrationProfile)
    end

    it 'bulk query ArbitrationRules' do
      api_basic_authorize("arbitration_rule_show_list")
      FactoryGirl.create(:arbitration_rule)
      test_collection_bulk_query(:arbitration_rules, arbitration_rules_url, ArbitrationRule)
    end

    it 'bulk query ArbitrationSettings' do
      api_basic_authorize("show_arbitration_setting")
      FactoryGirl.create(:arbitration_setting)
      test_collection_bulk_query(:arbitration_settings, arbitration_settings_url, ArbitrationSetting)
    end

    it "bulk query Availability Zones" do
      api_basic_authorize("availability_zone_show_list")
      FactoryGirl.create(:availability_zone)
      test_collection_bulk_query(:availability_zones, availability_zones_url, AvailabilityZone)
    end

    it "bulk query Blueprints" do
      api_basic_authorize("blueprint_show_list")
      FactoryGirl.create(:blueprint)
      test_collection_bulk_query(:blueprints, blueprints_url, Blueprint)
    end

    it "bulk query Categories" do
      api_basic_authorize("ops_settings")
      FactoryGirl.create(:category)
      test_collection_bulk_query(:categories, categories_url, Category)
    end

    it "bulk query Chargebacks" do
      api_basic_authorize("chargeback")
      FactoryGirl.create(:chargeback_rate)
      test_collection_bulk_query(:chargebacks, chargebacks_url, ChargebackRate)
    end

    it 'bulk query CloudNetworks' do
      api_basic_authorize("miq_cloud_networks_view")
      FactoryGirl.create(:cloud_network)
      test_collection_bulk_query(:cloud_networks, cloud_networks_url, CloudNetwork)
    end

    it "bulk query Clusters" do
      api_basic_authorize("ems_cluster_show_list")
      FactoryGirl.create(:ems_cluster)
      test_collection_bulk_query(:clusters, clusters_url, EmsCluster)
    end

    it "bulk query Conditions" do
      api_basic_authorize("condition")
      FactoryGirl.create(:condition)
      test_collection_bulk_query(:conditions, conditions_url, Condition)
    end

    it "bulk query Actions" do
      api_basic_authorize("action_show_list")
      FactoryGirl.create(:miq_action)
      test_collection_bulk_query(:actions, actions_url, MiqAction)
    end

    it "bulk query ContainerDeployments" do
      api_basic_authorize("container_deployment_show")
      FactoryGirl.create(:container_deployment)
      test_collection_bulk_query(:container_deployments, container_deployments_url, ContainerDeployment)
    end

    it "bulk query Data Stores" do
      api_basic_authorize("storage_show_list")
      FactoryGirl.create(:storage)
      test_collection_bulk_query(:data_stores, data_stores_url, Storage)
    end

    it "bulk query Events" do
      api_basic_authorize("event")
      FactoryGirl.create(:miq_event_definition)
      test_collection_bulk_query(:events, events_url, MiqEventDefinition)
    end

    it "bulk query Flavors" do
      api_basic_authorize("flavor_show_list")
      FactoryGirl.create(:flavor)
      test_collection_bulk_query(:flavors, flavors_url, Flavor)
    end

    it "bulk query Groups" do
      api_basic_authorize("rbac_group_show_list")
      group = FactoryGirl.create(:miq_group)
      test_collection_bulk_query(:groups, groups_url, MiqGroup, group.id)
    end

    it "bulk query Hosts" do
      api_basic_authorize("host_show_list")
      FactoryGirl.create(:host)
      test_collection_bulk_query(:hosts, hosts_url, Host)
    end

    it "bulk query Policies" do
      api_basic_authorize("policy_view")
      FactoryGirl.create(:miq_policy)
      test_collection_bulk_query(:policies, policies_url, MiqPolicy)
    end

    it "bulk query Policy Actions" do
      api_basic_authorize("control_explorer_view")
      FactoryGirl.create(:miq_action)
      test_collection_bulk_query(:policy_actions, policy_actions_url, MiqAction)
    end

    it "bulk query Policy Profiles" do
      api_basic_authorize("policy_profile_view")
      FactoryGirl.create(:miq_policy_set)
      test_collection_bulk_query(:policy_profiles, policy_profiles_url, MiqPolicySet)
    end

    it "bulk query Providers" do
      api_basic_authorize("ems_infra_show_list")
      FactoryGirl.create(:ext_management_system)
      test_collection_bulk_query(:providers, providers_url, ExtManagementSystem)
    end

    it "bulk query Provision Dialogs" do
      api_basic_authorize("miq_ae_customization_explorer")
      FactoryGirl.create(:miq_dialog)
      test_collection_bulk_query(:provision_dialogs, provision_dialogs_url, MiqDialog)
    end

    it "bulk query Provision Requests" do
      api_basic_authorize("miq_request_show_list")
      FactoryGirl.create(:miq_provision_request, :source => template, :requester => @user)
      test_collection_bulk_query(:provision_requests, provision_requests_url, MiqProvisionRequest)
    end

    it "bulk query Rates" do
      api_basic_authorize("chargeback_rates")
      FactoryGirl.create(:chargeback_rate_detail)
      test_collection_bulk_query(:rates, rates_url, ChargebackRateDetail)
    end

    it "bulk query Report Results" do
      api_basic_authorize("miq_report_view")
      FactoryGirl.create(:miq_report_result)
      test_collection_bulk_query(:results, results_url, MiqReportResult)
    end

    it "bulk query Requests" do
      api_basic_authorize("miq_request_show_list")
      FactoryGirl.create(:vm_migrate_request, :requester => @user)
      test_collection_bulk_query(:requests, requests_url, MiqRequest)
    end

    it "bulk query Resource Pools" do
      api_basic_authorize("resource_pool_show_list")
      FactoryGirl.create(:resource_pool)
      test_collection_bulk_query(:resource_pools, resource_pools_url, ResourcePool)
    end

    it "bulk query Roles" do
      api_basic_authorize("rbac_role_show_list")
      FactoryGirl.create(:miq_user_role)
      test_collection_bulk_query(:roles, roles_url, MiqUserRole)
    end

    it "bulk query Security Groups" do
      api_basic_authorize("security_group_show_list")
      FactoryGirl.create(:security_group)
      test_collection_bulk_query(:security_groups, security_groups_url, SecurityGroup)
    end

    it "bulk query Service Catalogs" do
      api_basic_authorize("svc_catalog_provision")
      FactoryGirl.create(:service_template_catalog)
      test_collection_bulk_query(:service_catalogs, service_catalogs_url, ServiceTemplateCatalog)
    end

    it "bulk query Service Dialogs" do
      api_basic_authorize("miq_ae_customization_explorer")
      FactoryGirl.create(:dialog, :label => "ServiceDialog1")
      test_collection_bulk_query(:service_dialogs, service_dialogs_url, Dialog)
    end

    it "bulk query Service Orders" do
      api_basic_authorize("svc_catalog_provision")
      FactoryGirl.create(:service_order, :user => @user)
      test_collection_bulk_query(:service_orders, service_orders_url, ServiceOrder)
    end

    it "bulk query Service Requests" do
      api_basic_authorize("miq_request_view")
      FactoryGirl.create(:service_template_provision_request, :requester => @user)
      test_collection_bulk_query(:service_requests, service_requests_url, ServiceTemplateProvisionRequest)
    end

    it "bulk query Service Templates" do
      api_basic_authorize("svc_catalog_provision")
      FactoryGirl.create(:service_template)
      test_collection_bulk_query(:service_templates, service_templates_url, ServiceTemplate)
    end

    it "bulk query Services" do
      api_basic_authorize("service_view")
      FactoryGirl.create(:service)
      test_collection_bulk_query(:services, services_url, Service)
    end

    it "bulk query Tags" do
      api_basic_authorize("ops_settings")
      FactoryGirl.create(:classification_cost_center_with_tags)
      test_collection_bulk_query(:tags, tags_url, Tag)
    end

    it "bulk query Tasks" do
      api_basic_authorize("tasks_view")
      FactoryGirl.create(:miq_task)
      test_collection_bulk_query(:tasks, tasks_url, MiqTask)
    end

    it "bulk query Templates" do
      api_basic_authorize("miq_template_show_list")
      template # create resource
      test_collection_bulk_query(:templates, templates_url, MiqTemplate)
    end

    it "bulk query Tenants" do
      api_basic_authorize "rbac_tenant_view"
      Tenant.seed
      test_collection_bulk_query(:tenants, tenants_url, Tenant)
    end

    it "bulk query Users" do
      api_basic_authorize("rbac_user_show_list")
      FactoryGirl.create(:user)
      test_collection_bulk_query(:users, users_url, User)
    end

    it "bulk query Vms" do
      api_basic_authorize("vm_show_list")
      FactoryGirl.create(:vm_vmware)
      test_collection_bulk_query(:vms, vms_url, Vm)
    end

    it "doing a bulk query renders actions for which the user is authorized" do
      vm = FactoryGirl.create(:vm_vmware)
      api_basic_authorize("vm_show_list", "vm_start")

      run_post(vms_url, gen_request(:query, [{"id" => vm.id, "href" => vms_url(vm.id)}]))

      expected = {
        "results" => [
          a_hash_including(
            "actions" => [
              a_hash_including(
                "name"   => "start",
                "method" => "post",
                "href"   => a_string_matching(vms_url(vm.id))
              )
            ]
          )
        ]
      }
      expect(response.parsed_body).to include(expected)
    end

    it "bulk query Vms with invalid guid fails" do
      FactoryGirl.create(:vm_vmware)
      api_basic_authorize "vm_show_list"

      run_post(vms_url, gen_request(:query, [{"guid" => "B999999D"}]))

      expect(response.parsed_body).to include_error_with_message("Invalid vms resource specified - guid=B999999D")
      expect(response).to have_http_status(:not_found)
    end

    it "bulk query Zones" do
      api_basic_authorize("zone")
      FactoryGirl.create(:zone, :name => "api zone")
      test_collection_bulk_query(:zones, zones_url, Zone)
    end

    it 'bulk query LoadBalancers' do
      api_basic_authorize("load_balancer_show_list")
      FactoryGirl.create(:load_balancer)
      test_collection_bulk_query(:load_balancers, load_balancers_url, LoadBalancer)
    end
  end
end
