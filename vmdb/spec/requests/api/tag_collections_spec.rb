#
# REST API Request Tests - Tags subcollection specs for Non-Vm collections
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

    FactoryGirl.create(:classification_department_with_tags)
    FactoryGirl.create(:classification_cost_center_with_tags)

    @tag1 = {:category => "department", :name => "finance", :path => "/managed/department/finance"}
    @tag2 = {:category => "cc",         :name => "001",     :path => "/managed/cc/001"}
  end

  def app
    Vmdb::Application
  end

  context "Provider Tag subcollection" do
    before(:each) do
      @provider          = @ems
      @provider_url      = "#{@cfme[:providers_url]}/#{@ems.id}"
      @provider_tags_url = "#{@provider_url}/tags"
    end

    it "query all tags of a Provider and verify tag category and names" do
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@provider, @tag1[:category], @tag1[:name])
      Classification.classify(@provider, @tag2[:category], @tag2[:name])

      @success = run_get "#{@provider_tags_url}?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("tags")
      expect(@result["count"]).to eq(Tag.count)
      expect(@result["resources"].size).to eq(2)
      results = @result["resources"]
      expect(resources_include_suffix?(results, "name", @tag1[:path])).to be_true
      expect(resources_include_suffix?(results, "name", @tag2[:path])).to be_true
    end

    it "assigns a tag to a Provider without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@provider_tags_url, gen_request(:assign,
                                                          :category => @tag1[:category],
                                                          :name     => @tag1[:name]))
      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "assigns a tag to a Provider" do
      update_user_role(@role, subcollection_action_identifier(:providers, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@provider_tags_url, gen_request(:assign,
                                                          :category => @tag1[:category],
                                                          :name     => @tag1[:name]))
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@provider_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
    end

    it "unassigns a tag from a Provider without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@provider_tags_url, gen_request(:unassign,
                                                          :category => @tag1[:category],
                                                          :name     => @tag1[:name]))
      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "unassigns a tag from a Provider" do
      update_user_role(@role, subcollection_action_identifier(:providers, :tags, :unassign))
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@provider, @tag1[:category], @tag1[:name])
      Classification.classify(@provider, @tag2[:category], @tag2[:name])

      @success = run_post(@provider_tags_url, gen_request(:unassign,
                                                          :category => @tag1[:category],
                                                          :name     => @tag1[:name]))
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@provider_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
      expect(@provider.tags.count).to eq(1)
      expect(@provider.tags.first.name).to eq(@tag2[:path])
    end
  end

  context "Host Tag subcollection" do
    before(:each) do
      @host_url      = "#{@cfme[:hosts_url]}/#{@host.id}"
      @host_tags_url = "#{@host_url}/tags"
    end

    it "query all tags of a Host and verify tag category and names" do
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@host, @tag1[:category], @tag1[:name])
      Classification.classify(@host, @tag2[:category], @tag2[:name])

      @success = run_get "#{@host_tags_url}?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("tags")
      expect(@result["count"]).to eq(Tag.count)
      expect(@result["resources"].size).to eq(2)
      results = @result["resources"]
      expect(resources_include_suffix?(results, "name", @tag1[:path])).to be_true
      expect(resources_include_suffix?(results, "name", @tag2[:path])).to be_true
    end

    it "assigns a tag to a Host without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@host_tags_url, gen_request(:assign,
                                                      :category => @tag1[:category],
                                                      :name     => @tag1[:name]))
      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "assigns a tag to a Host" do
      update_user_role(@role, subcollection_action_identifier(:hosts, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@host_tags_url, gen_request(:assign,
                                                      :category => @tag1[:category],
                                                      :name     => @tag1[:name]))
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@host_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
    end

    it "unassigns a tag from a Host without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@host_tags_url, gen_request(:unassign,
                                                      :category => @tag1[:category],
                                                      :name     => @tag1[:name]))
      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "unassigns a tag from a Host" do
      update_user_role(@role, subcollection_action_identifier(:hosts, :tags, :unassign))
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@host, @tag1[:category], @tag1[:name])
      Classification.classify(@host, @tag2[:category], @tag2[:name])

      @success = run_post(@host_tags_url, gen_request(:unassign,
                                                      :category => @tag1[:category],
                                                      :name     => @tag1[:name]))
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@host_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
      expect(@host.tags.count).to eq(1)
      expect(@host.tags.first.name).to eq(@tag2[:path])
    end
  end

  context "Data Store Tag subcollection" do
    before(:each) do
      @ds          = FactoryGirl.create(:storage, :name => "Storage 1", :store_type => "VMFS")
      @ds_url      = "#{@cfme[:data_stores_url]}/#{@ds.id}"
      @ds_tags_url = "#{@ds_url}/tags"
    end

    it "query all tags of a Data Store and verify tag category and names" do
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@ds, @tag1[:category], @tag1[:name])
      Classification.classify(@ds, @tag2[:category], @tag2[:name])

      @success = run_get "#{@ds_tags_url}?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("tags")
      expect(@result["count"]).to eq(Tag.count)
      expect(@result["resources"].size).to eq(2)
      results = @result["resources"]
      expect(resources_include_suffix?(results, "name", @tag1[:path])).to be_true
      expect(resources_include_suffix?(results, "name", @tag2[:path])).to be_true
    end

    it "assigns a tag to a Data Store without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@ds_tags_url, gen_request(:assign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "assigns a tag to a Data Store" do
      update_user_role(@role, subcollection_action_identifier(:data_stores, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@ds_tags_url, gen_request(:assign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@ds_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
    end

    it "unassigns a tag from a Data Store without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@ds_tags_url, gen_request(:unassign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "unassigns a tag from a Data Store" do
      update_user_role(@role, subcollection_action_identifier(:data_stores, :tags, :unassign))
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@ds, @tag1[:category], @tag1[:name])
      Classification.classify(@ds, @tag2[:category], @tag2[:name])

      @success = run_post(@ds_tags_url, gen_request(:unassign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@ds_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
      expect(@ds.tags.count).to eq(1)
      expect(@ds.tags.first.name).to eq(@tag2[:path])
    end
  end

  context "Resource Pool Tag subcollection" do
    before(:each) do
      @rp          = FactoryGirl.create(:resource_pool, :name => "Resource Pool 1")
      @rp_url      = "#{@cfme[:resource_pools_url]}/#{@rp.id}"
      @rp_tags_url = "#{@rp_url}/tags"
    end

    it "query all tags of a Resource Pool and verify tag category and names" do
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@rp, @tag1[:category], @tag1[:name])
      Classification.classify(@rp, @tag2[:category], @tag2[:name])

      @success = run_get "#{@rp_tags_url}?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("tags")
      expect(@result["count"]).to eq(Tag.count)
      expect(@result["resources"].size).to eq(2)
      results = @result["resources"]
      expect(resources_include_suffix?(results, "name", @tag1[:path])).to be_true
      expect(resources_include_suffix?(results, "name", @tag2[:path])).to be_true
    end

    it "assigns a tag to a Resource Pool without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@rp_tags_url, gen_request(:assign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "assigns a tag to a Resource Pool" do
      update_user_role(@role, subcollection_action_identifier(:resource_pools, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@rp_tags_url, gen_request(:assign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@rp_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
    end

    it "unassigns a tag from a Resource Pool without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@rp_tags_url, gen_request(:unassign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "unassigns a tag from a Resource Pool" do
      update_user_role(@role, subcollection_action_identifier(:resource_pools, :tags, :unassign))
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@rp, @tag1[:category], @tag1[:name])
      Classification.classify(@rp, @tag2[:category], @tag2[:name])

      @success = run_post(@rp_tags_url, gen_request(:unassign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@rp_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
      expect(@rp.tags.count).to eq(1)
      expect(@rp.tags.first.name).to eq(@tag2[:path])
    end
  end

  context "Cluster Tag subcollection" do
    before(:each) do
      @cluster = FactoryGirl.create(:ems_cluster,
                                    :name                  => "cluster 1",
                                    :ext_management_system => @ems,
                                    :hosts                 => [@host],
                                    :vms                   => [])

      @cluster_url      = "#{@cfme[:clusters_url]}/#{@cluster.id}"
      @cluster_tags_url = "#{@cluster_url}/tags"
    end

    it "query all tags of a Cluster and verify tag category and names" do
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@cluster, @tag1[:category], @tag1[:name])
      Classification.classify(@cluster, @tag2[:category], @tag2[:name])

      @success = run_get "#{@cluster_tags_url}?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("tags")
      expect(@result["count"]).to eq(Tag.count)
      expect(@result["resources"].size).to eq(2)
      results = @result["resources"]
      expect(resources_include_suffix?(results, "name", @tag1[:path])).to be_true
      expect(resources_include_suffix?(results, "name", @tag2[:path])).to be_true
    end

    it "assigns a tag to a Cluster without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@cluster_tags_url, gen_request(:assign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "assigns a tag to a Cluster" do
      update_user_role(@role, subcollection_action_identifier(:clusters, :tags, :assign))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@cluster_tags_url, gen_request(:assign, :category => @tag1[:category], :name => @tag1[:name]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@cluster_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
    end

    it "unassigns a tag from a Cluster without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@cluster_tags_url, gen_request(:unassign,
                                                         :category => @tag1[:category],
                                                         :name     => @tag1[:name]))
      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "unassigns a tag from a Cluster" do
      update_user_role(@role, subcollection_action_identifier(:clusters, :tags, :unassign))
      basic_authorize @cfme[:user], @cfme[:password]

      Classification.classify(@cluster, @tag1[:category], @tag1[:name])
      Classification.classify(@cluster, @tag2[:category], @tag2[:name])

      @success = run_post(@cluster_tags_url, gen_request(:unassign,
                                                         :category => @tag1[:category],
                                                         :name     => @tag1[:name]))
      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(1)
      result = results.first
      expect(result["success"]).to be_true
      expect(result["href"]).to match(@cluster_url)
      expect(result["tag_category"]).to eq(@tag1[:category])
      expect(result["tag_name"]).to eq(@tag1[:name])
      expect(@cluster.tags.count).to eq(1)
      expect(@cluster.tags.first.name).to eq(@tag2[:path])
    end
  end
end
