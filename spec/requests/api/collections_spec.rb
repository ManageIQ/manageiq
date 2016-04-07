#
# Rest API Collections Tests
#
describe ApiController do
  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :zone => zone) }
  let(:template) do
    FactoryGirl.create(:miq_template, :name => "template 1", :vendor => "vmware", :location => "template1.vmtx")
  end

  def test_collection_query(collection, collection_url, klass, attr = :id)
    api_basic_authorize

    run_get collection_url, :expand => "resources"

    expect_query_result(collection, klass.count, klass.count)
    expect_result_resources_to_include_data("resources", attr.to_s => klass.pluck(attr))
  end

  context "Collections" do
    it "query Automation Requests" do
      FactoryGirl.create(:automation_request)
      test_collection_query(:automation_requests, automation_requests_url, AutomationRequest)
    end

    it "query Availability Zones" do
      FactoryGirl.create(:availability_zone)
      test_collection_query(:availability_zones, availability_zones_url, AvailabilityZone)
    end

    it "query Categories" do
      FactoryGirl.create(:category)
      test_collection_query(:categories, categories_url, Category)
    end

    example "query Chargebacks" do
      FactoryGirl.create(:chargeback_rate)
      test_collection_query(:chargebacks, chargebacks_url, ChargebackRate)
    end

    it "query Clusters" do
      FactoryGirl.create(:ems_cluster)
      test_collection_query(:clusters, clusters_url, EmsCluster)
    end

    it "query Conditions" do
      FactoryGirl.create(:condition)
      test_collection_query(:conditions, conditions_url, Condition)
    end

    it "query Data Stores" do
      FactoryGirl.create(:storage)
      test_collection_query(:data_stores, data_stores_url, Storage)
    end

    it "query Events" do
      FactoryGirl.create(:miq_event_definition)
      test_collection_query(:events, events_url, MiqEventDefinition)
    end

    it "query Features" do
      FactoryGirl.create(:miq_product_feature, :identifier => "vm_auditing")
      test_collection_query(:features, features_url, MiqProductFeature)
    end

    it "query Flavors" do
      FactoryGirl.create(:flavor)
      test_collection_query(:flavors, flavors_url, Flavor)
    end

    it "query Groups" do
      FactoryGirl.create(:miq_group)
      test_collection_query(:groups, groups_url, MiqGroup)
    end

    it "query Hosts" do
      FactoryGirl.create(:host)
      test_collection_query(:hosts, hosts_url, Host, :guid)
    end

    it "query Pictures" do
      FactoryGirl.create(:picture)
      test_collection_query(:pictures, pictures_url, Picture)
    end

    it "query Policies" do
      FactoryGirl.create(:miq_policy)
      test_collection_query(:policies, policies_url, MiqPolicy)
    end

    it "query Policy Actions" do
      FactoryGirl.create(:miq_action)
      test_collection_query(:policy_actions, policy_actions_url, MiqAction)
    end

    it "query Policy Profiles" do
      FactoryGirl.create(:miq_policy_set)
      test_collection_query(:policy_profiles, policy_profiles_url, MiqPolicySet)
    end

    it "query Providers" do
      FactoryGirl.create(:ext_management_system)
      test_collection_query(:providers, providers_url, ExtManagementSystem, :guid)
    end

    it "query Provision Dialogs" do
      FactoryGirl.create(:miq_dialog)
      test_collection_query(:provision_dialogs, provision_dialogs_url, MiqDialog)
    end

    it "query Provision Requests" do
      FactoryGirl.create(:miq_provision_request, :source => template, :requester => @user)
      test_collection_query(:provision_requests, provision_requests_url, MiqProvisionRequest)
    end

    example "query Rates" do
      FactoryGirl.build(:chargeback_rate_detail)
      test_collection_query(:rates, rates_url, ChargebackRateDetail)
    end

    example "query Reports" do
      FactoryGirl.create(:miq_report)
      test_collection_query(:reports, reports_url, MiqReport)
    end

    it "query Report Results" do
      FactoryGirl.create(:miq_report_result)
      test_collection_query(:results, results_url, MiqReportResult)
    end

    it "query Request Tasks" do
      FactoryGirl.create(:miq_request_task)
      test_collection_query(:request_tasks, request_tasks_url, MiqRequestTask)
    end

    it "query Requests" do
      FactoryGirl.create(:vm_migrate_request, :requester => @user)
      test_collection_query(:requests, requests_url, MiqRequest)
    end

    it "query Resource Pools" do
      FactoryGirl.create(:resource_pool)
      test_collection_query(:resource_pools, resource_pools_url, ResourcePool)
    end

    it "query Roles" do
      FactoryGirl.create(:miq_user_role)
      test_collection_query(:roles, roles_url, MiqUserRole)
    end

    it "query Security Groups" do
      FactoryGirl.create(:security_group)
      test_collection_query(:security_groups, security_groups_url, SecurityGroup)
    end

    it "query Servers" do
      miq_server # create resource
      test_collection_query(:servers, servers_url, MiqServer, :guid)
    end

    it "query Service Catalogs" do
      FactoryGirl.create(:service_template_catalog)
      test_collection_query(:service_catalogs, service_catalogs_url, ServiceTemplateCatalog)
    end

    it "query Service Dialogs" do
      FactoryGirl.create(:dialog, :label => "ServiceDialog1")
      test_collection_query(:service_dialogs, service_dialogs_url, Dialog)
    end

    it "query Service Requests" do
      FactoryGirl.create(:service_template_provision_request, :requester => @user)
      test_collection_query(:service_requests, service_requests_url, ServiceTemplateProvisionRequest)
    end

    it "query Service Templates" do
      FactoryGirl.create(:service_template)
      test_collection_query(:service_templates, service_templates_url, ServiceTemplate, :guid)
    end

    it "query Services" do
      FactoryGirl.create(:service)
      test_collection_query(:services, services_url, Service)
    end

    it "query Tags" do
      FactoryGirl.create(:classification_cost_center_with_tags)
      test_collection_query(:tags, tags_url, Tag)
    end

    it "query Tasks" do
      FactoryGirl.create(:miq_task)
      test_collection_query(:tasks, tasks_url, MiqTask)
    end

    it "query Templates" do
      template # create resource
      test_collection_query(:templates, templates_url, MiqTemplate, :guid)
    end

    it "query Tenants" do
      api_basic_authorize "rbac_tenant_show_list"
      Tenant.seed
      test_collection_query(:tenants, tenants_url, Tenant)
    end

    it "query Users" do
      FactoryGirl.create(:user)
      test_collection_query(:users, users_url, User)
    end

    it "query Vms" do
      FactoryGirl.create(:vm_vmware)
      test_collection_query(:vms, vms_url, Vm, :guid)
    end

    it "query Zones" do
      FactoryGirl.create(:zone, :name => "api zone")
      test_collection_query(:zones, zones_url, Zone)
    end
  end
end
