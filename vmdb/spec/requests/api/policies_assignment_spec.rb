#
# REST API Request Tests - Policies and Policy Profiles Assignments
#
# Testing both assign and unassign actions for policies
# and policy profiles on the following collections
#   /api/vms/:id
#   /api/providers/:id
#   /api/hosts/:id
#   /api/resource_pools/:id
#   /api/clusters/:id
#   /api/templates/:id
#
# Targeting as follows:
#   /api/:collection/:id/policies
#       and
#   /api/:collection/:id/policy_profiles
#
require 'spec_helper'

describe ApiController do

  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env

    @zone       = FactoryGirl.create(:zone, :name => "api_zone")
    @miq_server = FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => @zone)
    @provider   = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host       = FactoryGirl.create(:host)
    @cluster    = FactoryGirl.create(:ems_cluster, :ext_management_system => @provider, :hosts => [@host], :vms => [])
    @rp         = FactoryGirl.create(:resource_pool, :name => "Resource Pool 1")
    @vm         = FactoryGirl.create(:vm)
    @template   = FactoryGirl.create(:miq_template, :name => "Tmpl 1", :vendor => "vmware", :location => "tmpl_1.vmtx")

    Host.any_instance.stub(:miq_proxy).and_return(@miq_server)

    # Creating:  policy_set_1 = [policy_1, policy_2]  and  policy_set_2 = [policy_3]

    @p1  = FactoryGirl.create(:miq_policy, :description => "Policy 1")
    @p2  = FactoryGirl.create(:miq_policy, :description => "Policy 2")
    @p3  = FactoryGirl.create(:miq_policy, :description => "Policy 3")

    @ps1 = FactoryGirl.create(:miq_policy_set, :description => "Policy Set 1")
    @ps2 = FactoryGirl.create(:miq_policy_set, :description => "Policy Set 2")

    @ps1.add_member(@p1)
    @ps1.add_member(@p2)

    @ps2.add_member(@p3)
  end

  def app
    Vmdb::Application
  end

  def test_policy_assign_no_role(object_policies_url)
    basic_authorize @cfme[:user], @cfme[:password]

    @success = run_post(object_policies_url, gen_request(:assign))

    expect(@success).to be_false
    expect(@code).to eq(403)
  end

  def test_policy_assign_invalid_policy(object_policies_url, collection, subcollection)
    update_user_role(@role, subcollection_action_identifier(collection, subcollection, :assign))
    basic_authorize @cfme[:user], @cfme[:password]

    @success = run_post(object_policies_url, gen_request_data(:assign, :href => "/api/#{subcollection}/999999"))

    expect(@success).to be_false
    expect(@code).to eq(404)
  end

  def test_policy_assign_invalid_policy_guid(object_url, object_policies_url, collection, subcollection)
    update_user_role(@role, subcollection_action_identifier(collection, subcollection, :assign))
    basic_authorize @cfme[:user], @cfme[:password]

    @success = run_post(object_policies_url, gen_request_data(:assign, :guid => "xyzzy"))

    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("results")
    result = @result["results"].first
    expect(result["success"]).to be_false
    expect(result["href"]).to match(object_url)
    expect(result["message"]).to match(/must specify a valid/i)
  end

  def test_assign_multiple_policies(object_url, object_policies_url, collection, subcollection, options = {})
    update_user_role(@role, subcollection_action_identifier(collection, subcollection, :assign))
    basic_authorize @cfme[:user], @cfme[:password]

    object = options[:object]
    policies = options[:policies]

    @success = run_post(object_policies_url, gen_requests(:assign, policies.collect { |p| {:guid => p.guid} }))

    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("results")
    results = @result["results"]
    expect(results.size).to eq(policies.size)
    sc_prefix = subcollection.to_s.singularize
    [results, policies].transpose.each do |result, policy|
      expect(result["success"]).to be_true
      expect(result["href"]).to match(object_url)
      expect(result["#{sc_prefix}_href"]).to match("/api/#{subcollection}/#{policy.id}")
    end
    expect(object.get_policies.size).to eq(policies.size)
    expect(object.get_policies.collect(&:guid)).to match_array(policies.collect(&:guid))
  end

  def test_policy_unassign_no_role(object_policies_url)
    basic_authorize @cfme[:user], @cfme[:password]

    @success = run_post(object_policies_url, gen_request(:unassign))

    expect(@success).to be_false
    expect(@code).to eq(403)
  end

  def test_policy_unassign_invalid_policy(object_policies_url, collection, subcollection)
    update_user_role(@role, subcollection_action_identifier(collection, subcollection, :unassign))
    basic_authorize @cfme[:user], @cfme[:password]

    @success = run_post(object_policies_url, gen_request_data(:unassign, :href => "/api/#{subcollection}/999999"))

    expect(@success).to be_false
    expect(@code).to eq(404)
  end

  def test_policy_unassign_invalid_policy_guid(object_url, object_policies_url, collection, subcollection)
    update_user_role(@role, subcollection_action_identifier(collection, subcollection, :unassign))
    basic_authorize @cfme[:user], @cfme[:password]

    @success = run_post(object_policies_url, gen_request_data(:unassign, :guid => "xyzzy"))

    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("results")
    result = @result["results"].first
    expect(result["success"]).to be_false
    expect(result["href"]).to match(object_url)
    expect(result["message"]).to match(/must specify a valid/i)
  end

  def test_unassign_multiple_policies(object_policies_url, collection, subcollection, options = {})
    update_user_role(@role, subcollection_action_identifier(collection, subcollection, :unassign))
    basic_authorize @cfme[:user], @cfme[:password]

    object = options[:object]

    [@p1, @p2, @p3].each { |p| object.add_policy(p) }
    @success = run_post(object_policies_url, gen_requests(:unassign, [{:guid => @p2.guid}, {:guid => @p3.guid}]))

    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("results")
    results = @result["results"]
    expect(results.size).to eq(2)
    expect(results.collect { |r| r["success"] }.uniq).to eq([true])
    expect(object.get_policies.size).to eq(1)
    expect(object.get_policies.first.guid).to eq(@p1.guid)
  end

  def test_unassign_multiple_policy_profiles(object_policies_url, collection, subcollection, options = {})
    update_user_role(@role, subcollection_action_identifier(collection, subcollection, :unassign))
    basic_authorize @cfme[:user], @cfme[:password]

    object = options[:object]
    [@ps1, @ps2].each { |ps| object.add_policy(ps) }
    @success = run_post(object_policies_url, gen_requests(:unassign, [{:guid => @ps2.guid}]))

    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("results")
    results = @result["results"]
    expect(results.size).to eq(1)
    expect(results.first["success"]).to eq(true)
    expect(object.get_policies.size).to eq(1)
    expect(object.get_policies.first.guid).to eq(@ps1.guid)
  end

  context "Provider policies subcollection assignment" do
    before(:each) do
      @provider_url = "#{@cfme[:providers_url]}/#{@provider.id}"
      @provider_policies_url = "#{@provider_url}/policies"
      @provider_policy_profiles_url = "#{@provider_url}/policy_profiles"
    end

    it "assign Provider policy without approriate role" do
      test_policy_assign_no_role(@provider_policies_url)
    end

    it "assign Provider policy with invalid href" do
      test_policy_assign_invalid_policy(@provider_policies_url, :providers, :policies)
    end

    it "assign Provider policy with invalid guid" do
      test_policy_assign_invalid_policy_guid(@provider_url, @provider_policies_url, :providers, :policies)
    end

    it "assign Provider multiple policies" do
      test_assign_multiple_policies(@provider_url,
                                    @provider_policies_url,
                                    :providers,
                                    :policies,
                                    :object   => @provider,
                                    :policies => [@p1, @p2])
    end

    it "unassign Provider policy without approriate role" do
      test_policy_unassign_no_role(@provider_policies_url)
    end

    it "unassign Provider policy with invalid href" do
      test_policy_unassign_invalid_policy(@provider_policies_url, :providers, :policies)
    end

    it "unassign Provider policy with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@provider_url, @provider_policies_url, :providers, :policies)
    end

    it "unassign Provider multiple policies" do
      test_unassign_multiple_policies(@provider_policies_url, :providers, :policies, :object => @provider)
    end
  end

  context "Provider policy profiles subcollection assignment" do
    before(:each) do
      @provider_url = "#{@cfme[:providers_url]}/#{@provider.id}"
      @provider_policies_url = "#{@provider_url}/policies"
      @provider_policy_profiles_url = "#{@provider_url}/policy_profiles"
    end

    it "assign Provider policy profile without approriate role" do
      test_policy_assign_no_role(@provider_policy_profiles_url)
    end

    it "assign Provider policy profile with invalid href" do
      test_policy_assign_invalid_policy(@provider_policy_profiles_url, :providers, :policy_profiles)
    end

    it "assign Provider policy profile with invalid guid" do
      test_policy_assign_invalid_policy_guid(@provider_url, @provider_policy_profiles_url, :providers, :policy_profiles)
    end

    it "assign Provider multiple policy profiles" do
      test_assign_multiple_policies(@provider_url,
                                    @provider_policy_profiles_url,
                                    :providers,
                                    :policy_profiles,
                                    :object   => @provider,
                                    :policies => [@ps1, @ps2])
    end

    it "unassign Provider policy profile without approriate role" do
      test_policy_unassign_no_role(@provider_policy_profiles_url)
    end

    it "unassign Provider policy profile with invalid href" do
      test_policy_unassign_invalid_policy(@provider_policy_profiles_url, :providers, :policy_profiles)
    end

    it "unassign Provider policy profile with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@provider_url,
                                               @provider_policy_profiles_url,
                                               :providers,
                                               :policy_profiles)
    end

    it "unassign Provider multiple policy profiles" do
      test_unassign_multiple_policy_profiles(@provider_policy_profiles_url,
                                             :providers,
                                             :policy_profiles,
                                             :object => @provider)
    end
  end

  context "Host policies subcollection assignments" do
    before(:each) do
      @host_url = "#{@cfme[:hosts_url]}/#{@host.id}"
      @host_policies_url = "#{@host_url}/policies"
      @host_policy_profiles_url = "#{@host_url}/policy_profiles"
    end

    it "assign Host policy without approriate role" do
      test_policy_assign_no_role(@host_policies_url)
    end

    it "assign Host policy with invalid href" do
      test_policy_assign_invalid_policy(@host_policies_url, :hosts, :policies)
    end

    it "assign Host policy with invalid guid" do
      test_policy_assign_invalid_policy_guid(@host_url, @host_policies_url, :hosts, :policies)
    end

    it "assign Host multiple policies" do
      test_assign_multiple_policies(@host_url,
                                    @host_policies_url,
                                    :hosts,
                                    :policies,
                                    :object   => @host,
                                    :policies => [@p1, @p2])
    end

    it "unassign Host policy without approriate role" do
      test_policy_unassign_no_role(@host_policies_url)
    end

    it "unassign Host policy with invalid href" do
      test_policy_unassign_invalid_policy(@host_policies_url, :hosts, :policies)
    end

    it "unassign Host policy with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@host_url, @host_policies_url, :hosts, :policies)
    end

    it "unassign Host multiple policies" do
      test_unassign_multiple_policies(@host_policies_url, :hosts, :policies, :object => @host)
    end
  end

  context "Host policy profiles subcollection assignments" do
    before(:each) do
      @host_url = "#{@cfme[:hosts_url]}/#{@host.id}"
      @host_policies_url = "#{@host_url}/policies"
      @host_policy_profiles_url = "#{@host_url}/policy_profiles"
    end

    it "assign Host policy profile without approriate role" do
      test_policy_assign_no_role(@host_policy_profiles_url)
    end

    it "assign Host policy profile with invalid href" do
      test_policy_assign_invalid_policy(@host_policy_profiles_url, :hosts, :policy_profiles)
    end

    it "assign Host policy profile with invalid guid" do
      test_policy_assign_invalid_policy_guid(@host_url, @host_policy_profiles_url, :hosts, :policy_profiles)
    end

    it "assign Host multiple policy profiles" do
      test_assign_multiple_policies(@host_url,
                                    @host_policy_profiles_url,
                                    :hosts,
                                    :policy_profiles,
                                    :object   => @host,
                                    :policies => [@ps1, @ps2])
    end

    it "unassign Host policy profile without approriate role" do
      test_policy_unassign_no_role(@host_policy_profiles_url)
    end

    it "unassign Host policy profile with invalid href" do
      test_policy_unassign_invalid_policy(@host_policy_profiles_url, :hosts, :policy_profiles)
    end

    it "unassign Host policy profile with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@host_url,
                                               @host_policy_profiles_url,
                                               :hosts,
                                               :policy_profiles)
    end

    it "unassign Host multiple policy profiles" do
      test_unassign_multiple_policy_profiles(@host_policy_profiles_url,
                                             :hosts,
                                             :policy_profiles,
                                             :object => @host)
    end
  end

  context "Resource Pool policies subcollection assignments" do
    before(:each) do
      @rp_url = "#{@cfme[:resource_pools_url]}/#{@rp.id}"
      @rp_policies_url = "#{@rp_url}/policies"
      @rp_policy_profiles_url = "#{@rp_url}/policy_profiles"
    end

    it "assign Resource Pool policy without appropriate role" do
      test_policy_assign_no_role(@rp_policies_url)
    end

    it "assign Resource Pool policy with invalid href" do
      test_policy_assign_invalid_policy(@rp_policies_url, :resource_pools, :policies)
    end

    it "assign Resource Pool policy with invalid guid" do
      test_policy_assign_invalid_policy_guid(@rp_url, @rp_policies_url, :resource_pools, :policies)
    end

    it "assign Resource Pool multiple policies" do
      test_assign_multiple_policies(@rp_url,
                                    @rp_policies_url,
                                    :resource_pools,
                                    :policies,
                                    :object   => @rp,
                                    :policies => [@p1, @p2])
    end

    it "unassign Resource Pool policy without approriate role" do
      test_policy_unassign_no_role(@rp_policies_url)
    end

    it "unassign Resource Pool policy with invalid href" do
      test_policy_unassign_invalid_policy(@rp_policies_url, :resource_pools, :policies)
    end

    it "unassign Resource Pool policy with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@rp_url, @rp_policies_url, :resource_pools, :policies)
    end

    it "unassign Resource Pool multiple policies" do
      test_unassign_multiple_policies(@rp_policies_url, :resource_pools, :policies, :object => @rp)
    end
  end

  context "Resource Pool policy profiles subcollection assignments" do
    before(:each) do
      @rp_url = "#{@cfme[:resource_pools_url]}/#{@rp.id}"
      @rp_policies_url = "#{@rp_url}/policies"
      @rp_policy_profiles_url = "#{@rp_url}/policy_profiles"
    end

    it "assign Resource Pool policy profile without approriate role" do
      test_policy_assign_no_role(@rp_policy_profiles_url)
    end

    it "assign Resource Pool policy profile with invalid href" do
      test_policy_assign_invalid_policy(@rp_policy_profiles_url, :resource_pools, :policy_profiles)
    end

    it "assign Resource Pool policy profile with invalid guid" do
      test_policy_assign_invalid_policy_guid(@rp_url, @rp_policy_profiles_url, :resource_pools, :policy_profiles)
    end

    it "assign Resource Pool multiple policy profiles" do
      test_assign_multiple_policies(@rp_url,
                                    @rp_policy_profiles_url,
                                    :resource_pools,
                                    :policy_profiles,
                                    :object   => @rp,
                                    :policies => [@ps1, @ps2])
    end

    it "unassign Resource Pool policy profile without approriate role" do
      test_policy_unassign_no_role(@rp_policy_profiles_url)
    end

    it "unassign Resource Pool policy profile with invalid href" do
      test_policy_unassign_invalid_policy(@rp_policy_profiles_url, :resource_pools, :policy_profiles)
    end

    it "unassign Resource Pool policy profile with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@rp_url,
                                               @rp_policy_profiles_url,
                                               :resource_pools,
                                               :policy_profiles)
    end

    it "unassign Resource Pool multiple policy profiles" do
      test_unassign_multiple_policy_profiles(@rp_policy_profiles_url,
                                             :resource_pools,
                                             :policy_profiles,
                                             :object => @rp)
    end
  end

  context "Cluster policies subcollection assignments" do
    before(:each) do
      @cluster_url = "#{@cfme[:clusters_url]}/#{@cluster.id}"
      @cluster_policies_url = "#{@cluster_url}/policies"
      @cluster_policy_profiles_url = "#{@cluster_url}/policy_profiles"
    end

    it "assign Cluster policy without approriate role" do
      test_policy_assign_no_role(@cluster_policies_url)
    end

    it "assign Cluster policy with invalid href" do
      test_policy_assign_invalid_policy(@cluster_policies_url, :clusters, :policies)
    end

    it "assign Cluster policy with invalid guid" do
      test_policy_assign_invalid_policy_guid(@cluster_url, @cluster_policies_url, :clusters, :policies)
    end

    it "assign Cluster multiple policies" do
      test_assign_multiple_policies(@cluster_url,
                                    @cluster_policies_url,
                                    :clusters,
                                    :policies,
                                    :object   => @cluster,
                                    :policies => [@p1, @p2])
    end

    it "unassign Cluster policy without approriate role" do
      test_policy_unassign_no_role(@cluster_policies_url)
    end

    it "unassign Cluster policy with invalid href" do
      test_policy_unassign_invalid_policy(@cluster_policies_url, :clusters, :policies)
    end

    it "unassign Cluster policy with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@cluster_url, @cluster_policies_url, :clusters, :policies)
    end

    it "unassign Cluster multiple policies" do
      test_unassign_multiple_policies(@cluster_policies_url, :clusters, :policies, :object => @cluster)
    end
  end

  context "Cluster policy profiles subcollection assignments" do
    before(:each) do
      @cluster_url = "#{@cfme[:clusters_url]}/#{@cluster.id}"
      @cluster_policies_url = "#{@cluster_url}/policies"
      @cluster_policy_profiles_url = "#{@cluster_url}/policy_profiles"
    end

    it "assign Cluster policy profile without approriate role" do
      test_policy_assign_no_role(@cluster_policy_profiles_url)
    end

    it "assign Cluster policy profile with invalid href" do
      test_policy_assign_invalid_policy(@cluster_policy_profiles_url, :clusters, :policy_profiles)
    end

    it "assign Cluster policy profile with invalid guid" do
      test_policy_assign_invalid_policy_guid(@cluster_url, @cluster_policy_profiles_url, :clusters, :policy_profiles)
    end

    it "assign Cluster multiple policy profiles" do
      test_assign_multiple_policies(@cluster_url,
                                    @cluster_policy_profiles_url,
                                    :clusters,
                                    :policy_profiles,
                                    :object   => @cluster,
                                    :policies => [@ps1, @ps2])
    end

    it "unassign Cluster policy profile without approriate role" do
      test_policy_unassign_no_role(@cluster_policy_profiles_url)
    end

    it "unassign Cluster policy profile with invalid href" do
      test_policy_unassign_invalid_policy(@cluster_policy_profiles_url, :clusters, :policy_profiles)
    end

    it "unassign Cluster policy profile with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@cluster_url,
                                               @cluster_policy_profiles_url,
                                               :clusters,
                                               :policy_profiles)
    end

    it "unassign Cluster multiple policy profiles" do
      test_unassign_multiple_policy_profiles(@cluster_policy_profiles_url,
                                             :clusters,
                                             :policy_profiles,
                                             :object => @cluster)
    end
  end

  context "Vms policies subcollection assignments" do
    before(:each) do
      @vm_url = "#{@cfme[:vms_url]}/#{@vm.id}"
      @vm_policies_url = "#{@vm_url}/policies"
      @vm_policy_profiles_url = "#{@vm_url}/policy_profiles"
    end

    it "assign Vm policy without approriate role" do
      test_policy_assign_no_role(@vm_policies_url)
    end

    it "assign Vm policy with invalid href" do
      test_policy_assign_invalid_policy(@vm_policies_url, :vms, :policies)
    end

    it "assign Vm policy with invalid guid" do
      test_policy_assign_invalid_policy_guid(@vm_url, @vm_policies_url, :vms, :policies)
    end

    it "assign Vm multiple policies" do
      test_assign_multiple_policies(@vm_url,
                                    @vm_policies_url,
                                    :vms,
                                    :policies,
                                    :object   => @vm,
                                    :policies => [@p1, @p2])
    end

    it "unassign Vm policy without approriate role" do
      test_policy_unassign_no_role(@vm_policies_url)
    end

    it "unassign Vm policy with invalid href" do
      test_policy_unassign_invalid_policy(@vm_policies_url, :vms, :policies)
    end

    it "unassign Vm policy with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@vm_url, @vm_policies_url, :vms, :policies)
    end

    it "unassign Vm multiple policies" do
      test_unassign_multiple_policies(@vm_policies_url, :vms, :policies, :object => @vm)
    end
  end

  context "Vms policy profiles subcollection assignments" do
    before(:each) do
      @vm_url = "#{@cfme[:vms_url]}/#{@vm.id}"
      @vm_policies_url = "#{@vm_url}/policies"
      @vm_policy_profiles_url = "#{@vm_url}/policy_profiles"
    end

    it "assign Vm policy profile without approriate role" do
      test_policy_assign_no_role(@vm_policy_profiles_url)
    end

    it "assign Vm policy profile with invalid href" do
      test_policy_assign_invalid_policy(@vm_policy_profiles_url, :vms, :policy_profiles)
    end

    it "assign Vm policy profile with invalid guid" do
      test_policy_assign_invalid_policy_guid(@vm_url, @vm_policy_profiles_url, :vms, :policy_profiles)
    end

    it "assign Vm multiple policy profiles" do
      test_assign_multiple_policies(@vm_url,
                                    @vm_policy_profiles_url,
                                    :vms,
                                    :policy_profiles,
                                    :object   => @vm,
                                    :policies => [@ps1, @ps2])
    end

    it "unassign Vm policy profile without approriate role" do
      test_policy_unassign_no_role(@vm_policy_profiles_url)
    end

    it "unassign Vm policy profile with invalid href" do
      test_policy_unassign_invalid_policy(@vm_policy_profiles_url, :vms, :policy_profiles)
    end

    it "unassign Vm policy profile with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@vm_url,
                                               @vm_policy_profiles_url,
                                               :vms,
                                               :policy_profiles)
    end

    it "unassign Vm multiple policy profiles" do
      test_unassign_multiple_policy_profiles(@vm_policy_profiles_url,
                                             :vms,
                                             :policy_profiles,
                                             :object => @vm)
    end
  end

  context "Template policies subcollection assignments" do
    before(:each) do
      @template_url = "#{@cfme[:templates_url]}/#{@template.id}"
      @template_policies_url = "#{@template_url}/policies"
      @template_policy_profiles_url = "#{@template_url}/policy_profiles"
    end

    it "assign Template policy without approriate role" do
      test_policy_assign_no_role(@template_policies_url)
    end

    it "assign Template policy with invalid href" do
      test_policy_assign_invalid_policy(@template_policies_url, :templates, :policies)
    end

    it "assign Template policy with invalid guid" do
      test_policy_assign_invalid_policy_guid(@template_url, @template_policies_url, :templates, :policies)
    end

    it "assign Template multiple policies" do
      test_assign_multiple_policies(@template_url,
                                    @template_policies_url,
                                    :templates,
                                    :policies,
                                    :object   => @template,
                                    :policies => [@p1, @p2])
    end

    it "unassign Template policy without approriate role" do
      test_policy_unassign_no_role(@template_policies_url)
    end

    it "unassign Template policy with invalid href" do
      test_policy_unassign_invalid_policy(@template_policies_url, :templates, :policies)
    end

    it "unassign Template policy with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@template_url, @template_policies_url, :templates, :policies)
    end

    it "unassign Template multiple policies" do
      test_unassign_multiple_policies(@template_policies_url, :templates, :policies, :object => @template)
    end
  end

  context "Template policies subcollection assignments" do
    before(:each) do
      @template_url = "#{@cfme[:templates_url]}/#{@template.id}"
      @template_policies_url = "#{@template_url}/policies"
      @template_policy_profiles_url = "#{@template_url}/policy_profiles"
    end

    it "assign Template policy profile without approriate role" do
      test_policy_assign_no_role(@template_policy_profiles_url)
    end

    it "assign Template policy profile with invalid href" do
      test_policy_assign_invalid_policy(@template_policy_profiles_url, :templates, :policy_profiles)
    end

    it "assign Template policy profile with invalid guid" do
      test_policy_assign_invalid_policy_guid(@template_url, @template_policy_profiles_url, :templates, :policy_profiles)
    end

    it "assign Template multiple policy profiles" do
      test_assign_multiple_policies(@template_url,
                                    @template_policy_profiles_url,
                                    :templates,
                                    :policy_profiles,
                                    :object   => @template,
                                    :policies => [@ps1, @ps2])
    end

    it "unassign Template policy profile without approriate role" do
      test_policy_unassign_no_role(@template_policy_profiles_url)
    end

    it "unassign Template policy profile with invalid href" do
      test_policy_unassign_invalid_policy(@template_policy_profiles_url, :templates, :policy_profiles)
    end

    it "unassign Template policy profile with invalid guid" do
      test_policy_unassign_invalid_policy_guid(@template_url,
                                               @template_policy_profiles_url,
                                               :templates,
                                               :policy_profiles)
    end

    it "unassign Template multiple policy profiles" do
      test_unassign_multiple_policy_profiles(@template_policy_profiles_url,
                                             :templates,
                                             :policy_profiles,
                                             :object => @template)
    end
  end
end
