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
require 'spec_helper'

describe ApiController do

  include Rack::Test::Methods

  before(:each) do
    init_api_spec_env

    @zone       = FactoryGirl.create(:zone, :name => "api_zone")
    @miq_server = FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => @zone)
    @ems        = FactoryGirl.create(:ems_vmware, :zone => @zone)
    @host       = FactoryGirl.create(:host)

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

    @p_guids     = [@p1.guid, @p2.guid]
    @p_all_guids = [@p1.guid, @p2.guid, @p3.guid]
  end

  def app
    Vmdb::Application
  end

  def test_no_policy_query(object_policies_url)
    basic_authorize @cfme[:user], @cfme[:password]

    @success = run_get object_policies_url

    expect(@code).to eq(200)
    expect(@result).to have_key("name")
    expect(@result["name"]).to eq("policies")
    expect(@result["resources"]).to be_empty
  end

  def test_no_policy_profile_query(object_policy_profiles_url)
    basic_authorize @cfme[:user], @cfme[:password]

    @success = run_get object_policy_profiles_url

    expect(@code).to eq(200)
    expect(@result).to have_key("name")
    expect(@result["name"]).to eq("policy_profiles")
    expect(@result["resources"]).to be_empty
  end

  def test_single_policy_query(object, object_policies_url)
    basic_authorize @cfme[:user], @cfme[:password]

    object.add_policy(@p1)
    object.add_policy(@ps2)

    @success = run_get "#{object_policies_url}?expand=resources"

    expect(@code).to eq(200)
    expect(@result).to have_key("name")
    expect(@result["name"]).to eq("policies")
    expect(@result["resources"].size).to eq(1)
    result = @result["resources"].first
    expect(result["name"]).to eq(@p1.name)
    expect(result["description"]).to eq(@p1.description)
    expect(result["guid"]).to eq(@p1.guid)
  end

  def test_multiple_policy_query(object, object_policies_url)
    basic_authorize @cfme[:user], @cfme[:password]

    object.add_policy(@p1)
    object.add_policy(@p2)
    object.add_policy(@ps2)

    @success = run_get "#{object_policies_url}?expand=resources"

    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("name")
    expect(@result["name"]).to eq("policies")
    expect(@result["resources"].size).to eq(2)
    results = @result["resources"]
    expect([results.first["guid"], results.last["guid"]]).to match_array(@p_guids)
  end

  def test_policy_profile_query(object, object_policy_profiles_url)
    basic_authorize @cfme[:user], @cfme[:password]

    object.add_policy(@p1)
    object.add_policy(@ps2)

    @success = run_get "#{object_policy_profiles_url}?expand=resources"

    expect(@success).to be_true
    expect(@code).to eq(200)
    expect(@result).to have_key("name")
    expect(@result["name"]).to eq("policy_profiles")
    expect(@result["resources"].size).to eq(1)
    result = @result["resources"].first
    expect(result["guid"]).to eq(@ps2.guid)
  end

  context "Policy collection" do
    it "query invalid policy" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:policies_url]}/999999"

      expect(@code).to eq(404)
    end

    it "query policies" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @cfme[:policies_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policies")
      expect(@result["resources"].size).to eq(3)
      results = @result["resources"]
      expect(resources_include_suffix?(results, "href", "#{@cfme[:policies_url]}/#{@p1.id}")).to be_true
      expect(resources_include_suffix?(results, "href", "#{@cfme[:policies_url]}/#{@p2.id}")).to be_true
      expect(resources_include_suffix?(results, "href", "#{@cfme[:policies_url]}/#{@p3.id}")).to be_true
    end

    it "query policies in expanded form" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:policies_url]}?expand=resources"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policies")
      expect(@result["resources"].size).to eq(3)
      guids = @result["resources"].collect { |r| r["guid"] }
      expect(guids).to match_array(@p_all_guids)
    end
  end

  context "Policy Profile collection" do
    before(:each) do
      @policy_profile     = @ps1
      @policy_profile_url = "#{@cfme[:policy_profiles_url]}/#{@policy_profile.id}"
    end

    it "query invalid policy profile" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@cfme[:policy_profiles_url]}/999999"

      expect(@code).to eq(404)
    end

    it "query Policy Profiles" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @cfme[:policy_profiles_url]

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policy_profiles")
      expect(@result["resources"].size).to eq(2)
      results = @result["resources"]
      expect(resources_include_suffix?(results, "href", "#{@cfme[:policy_profiles_url]}/#{@ps1.id}")).to be_true
      expect(resources_include_suffix?(results, "href", "#{@cfme[:policy_profiles_url]}/#{@ps2.id}")).to be_true
    end

    it "query individual Policy Profile" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get @policy_profile_url

      expect(@code).to eq(200)
      expect(@result["name"]).to eq(@policy_profile.name)
      expect(@result["description"]).to eq(@policy_profile.description)
      expect(@result["guid"]).to eq(@policy_profile.guid)
    end

    it "query Policy Profile policies subcollection" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@policy_profile_url}/policies?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("policies")
      expect(@result["resources"].size).to eq(2)
      results = @result["resources"]
      expect([results.first["guid"], results.last["guid"]]).to match_array(@p_guids)
    end

    it "query Policy Profile with expanded policies subcollection" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@policy_profile_url}?expand=policies"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq(@policy_profile.name)
      expect(@result["description"]).to eq(@policy_profile.description)
      expect(@result["guid"]).to eq(@policy_profile.guid)
      expect(@result).to have_key("policies")
      policies = @result["policies"]
      expect(policies.size).to eq(2)
      expect([policies.first["guid"], policies.last["guid"]]).to match_array(@p_guids)
    end
  end

  context "Provider policies subcollection" do
    before(:each) do
      @provider = @ems

      @provider_url = "#{@cfme[:providers_url]}/#{@provider.id}"
      @provider_policies_url = "#{@provider_url}/policies"
      @provider_policy_profiles_url = "#{@provider_url}/policy_profiles"
    end

    it "query Provider policies with no policies defined" do
      test_no_policy_query(@provider_policies_url)
    end

    it "query Provider policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(@provider_policy_profiles_url)
    end

    it "query Provider policies with one policy defined" do
      test_single_policy_query(@provider, @provider_policies_url)
    end

    it "query Provider policies with multiple policies defined" do
      test_multiple_policy_query(@provider, @provider_policies_url)
    end

    it "query Provider policy profiles" do
      test_policy_profile_query(@provider, @provider_policy_profiles_url)
    end
  end

  context "Host policies subcollection" do
    before(:each) do
      @host1 = @host

      @host1_url = "#{@cfme[:hosts_url]}/#{@host1.id}"
      @host1_policies_url = "#{@host1_url}/policies"
      @host1_policy_profiles_url = "#{@host1_url}/policy_profiles"
    end

    it "query Host policies with no policies defined" do
      test_no_policy_query(@host1_policies_url)
    end

    it "query Host policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(@host1_policy_profiles_url)
    end

    it "query Host policies with one policy defined" do
      test_single_policy_query(@host1, @host1_policies_url)
    end

    it "query Host policies with multiple policies defined" do
      test_multiple_policy_query(@host1, @host1_policies_url)
    end

    it "query Host policy profiles" do
      test_policy_profile_query(@host1, @host1_policy_profiles_url)
    end
  end

  context "Resource Pool policies subcollection" do
    before(:each) do
      @rp = FactoryGirl.create(:resource_pool, :name => "Resource Pool 1")

      @rp_url = "#{@cfme[:resource_pools_url]}/#{@rp.id}"
      @rp_policies_url = "#{@rp_url}/policies"
      @rp_policy_profiles_url = "#{@rp_url}/policy_profiles"
    end

    it "query Resource Pool policies with no policies defined" do
      test_no_policy_query(@rp_policies_url)
    end

    it "query Resource Pool policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(@rp_policy_profiles_url)
    end

    it "query Resource Pool policies with one policy defined" do
      test_single_policy_query(@rp, @rp_policies_url)
    end

    it "query Resource Pool policies with multiple policies defined" do
      test_multiple_policy_query(@rp, @rp_policies_url)
    end

    it "query Resource Pool policy profiles" do
      test_policy_profile_query(@rp, @rp_policy_profiles_url)
    end
  end

  context "Cluster policies subcollection" do
    before(:each) do
      @cluster = FactoryGirl.create(:ems_cluster,
                                    :name                  => "Cluster 1",
                                    :ext_management_system => @ems,
                                    :hosts                 => [@host],
                                    :vms                   => [])

      @cluster_url = "#{@cfme[:clusters_url]}/#{@cluster.id}"
      @cluster_policies_url = "#{@cluster_url}/policies"
      @cluster_policy_profiles_url = "#{@cluster_url}/policy_profiles"
    end

    it "query Cluster policies with no policies defined" do
      test_no_policy_query(@cluster_policies_url)
    end

    it "query Cluster policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(@cluster_policy_profiles_url)
    end

    it "query Cluster policies with one policy defined" do
      test_single_policy_query(@cluster, @cluster_policies_url)
    end

    it "query Cluster policies with multiple policies defined" do
      test_multiple_policy_query(@cluster, @cluster_policies_url)
    end

    it "query Cluster policy profiles" do
      test_policy_profile_query(@cluster, @cluster_policy_profiles_url)
    end
  end

  context "Vms policies subcollection" do
    before(:each) do
      @vm1 = FactoryGirl.create(:vm)

      @vm1_url = "#{@cfme[:vms_url]}/#{@vm1.id}"
      @vm1_policies_url = "#{@vm1_url}/policies"
      @vm1_policy_profiles_url = "#{@vm1_url}/policy_profiles"
    end

    it "query Vm policies with no policies defined" do
      test_no_policy_query(@vm1_policies_url)
    end

    it "query Vm policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(@vm1_policy_profiles_url)
    end

    it "query Vm policies with one policy defined" do
      test_single_policy_query(@vm1, @vm1_policies_url)
    end

    it "query Vm policies with multiple policies defined" do
      test_multiple_policy_query(@vm1, @vm1_policies_url)
    end

    it "query Vm policy profiles" do
      test_policy_profile_query(@vm1, @vm1_policy_profiles_url)
    end
  end

  context "Template policies subcollection" do
    before(:each) do
      @template = FactoryGirl.create(:miq_template,
                                     :name     => "Template 1",
                                     :vendor   => "vmware",
                                     :location => "template_1.vmtx")

      @template_url = "#{@cfme[:templates_url]}/#{@template.id}"
      @template_policies_url = "#{@template_url}/policies"
      @template_policy_profiles_url = "#{@template_url}/policy_profiles"
    end

    it "query Template policies with no policies defined" do
      test_no_policy_query(@template_policies_url)
    end

    it "query Template policy profiles with no policy profiles defined" do
      test_no_policy_profile_query(@template_policy_profiles_url)
    end

    it "query Template policies with one policy defined" do
      test_single_policy_query(@template, @template_policies_url)
    end

    it "query Template policies with multiple policies defined" do
      test_multiple_policy_query(@template, @template_policies_url)
    end

    it "query Template policy profile" do
      test_policy_profile_query(@template, @template_policy_profiles_url)
    end
  end
end
