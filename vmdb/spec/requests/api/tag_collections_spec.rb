#
# REST API Request Tests - Tags subcollection specs for Non-Vm collections
#
require 'spec_helper'

describe ApiController do

  include Rack::Test::Methods

  let(:zone)         { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server)   { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)          { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)         { FactoryGirl.create(:host) }

  let(:tag1)         { {:category => "department", :name => "finance", :path => "/managed/department/finance"} }
  let(:tag2)         { {:category => "cc",         :name => "001",     :path => "/managed/cc/001"} }
  let(:tag_paths)    { [tag1[:path], tag2[:path]] }
  let(:tag_count)    { Tag.count }

  def classify_resource(resource)
    Classification.classify(resource, tag1[:category], tag1[:name])
    Classification.classify(resource, tag2[:category], tag2[:name])
  end

  def tag1_results(resource_href)
    [{:success => true, :href => resource_href, :tag_category => tag1[:category], :tag_name => tag1[:name]}]
  end

  def verify_resource_has_single_tag_left(resource)
    expect(resource.tags.count).to eq(1)
    expect(resource.tags.first.name).to eq(tag2[:path])
  end

  before(:each) do
    init_api_spec_env

    FactoryGirl.create(:classification_department_with_tags)
    FactoryGirl.create(:classification_cost_center_with_tags)
  end

  def app
    Vmdb::Application
  end

  context "Provider Tag subcollection" do
    let(:provider)          { ems }
    let(:provider_url)      { providers_url(provider.id) }
    let(:provider_tags_url) { "#{provider_url}/tags" }

    context "query all tags of a Provider and verify tag category and names" do
      before do
        api_basic_authorize
        classify_resource(provider)

        run_get "#{provider_tags_url}?expand=resources"
      end

      it "query_result" do
        expect_query_result(:tags, 2, :tag_count)
        expect_result_resources_to_include_data("resources", "name" => :tag_paths)
      end
    end

    context "assigns a tag to a Provider without appropriate role" do
      before do
        api_basic_authorize

        run_post(provider_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "assigns a tag to a Provider" do
      before do
        api_basic_authorize subcollection_action_identifier(:providers, :tags, :assign)

        run_post(provider_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(provider_url))
      end
    end

    context "unassigns a tag from a Provider without appropriate role" do
      before do
        api_basic_authorize

        run_post(provider_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "unassigns a tag from a Provider" do
      before do
        api_basic_authorize subcollection_action_identifier(:providers, :tags, :unassign)
        classify_resource(provider)

        run_post(provider_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(provider_url))
        verify_resource_has_single_tag_left(provider)
      end
    end
  end

  context "Host Tag subcollection" do
    let(:host_url)      { hosts_url(host.id) }
    let(:host_tags_url) { "#{host_url}/tags" }

    context "query all tags of a Host and verify tag category and names" do
      before do
        api_basic_authorize
        classify_resource(host)

        run_get "#{host_tags_url}?expand=resources"
      end

      it "query_result" do
        expect_query_result(:tags, 2, :tag_count)
        expect_result_resources_to_include_data("resources", "name" => :tag_paths)
      end
    end

    context "assigns a tag to a Host without appropriate role" do
      before do
        api_basic_authorize

        run_post(host_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "assigns a tag to a Host" do
      before do
        api_basic_authorize subcollection_action_identifier(:hosts, :tags, :assign)

        run_post(host_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(host_url))
      end
    end

    context "unassigns a tag from a Host without appropriate role" do
      before do
        api_basic_authorize

        run_post(host_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "unassigns a tag from a Host" do
      before do
        api_basic_authorize subcollection_action_identifier(:hosts, :tags, :unassign)
        classify_resource(host)

        run_post(host_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(host_url))
        verify_resource_has_single_tag_left(host)
      end
    end
  end

  context "Data Store Tag subcollection" do
    let(:ds)          { FactoryGirl.create(:storage, :name => "Storage 1", :store_type => "VMFS") }
    let(:ds_url)      { data_stores_url(ds.id) }
    let(:ds_tags_url) { "#{ds_url}/tags" }

    context "query all tags of a Data Store and verify tag category and names" do
      before do
        api_basic_authorize
        classify_resource(ds)

        run_get "#{ds_tags_url}?expand=resources"
      end

      it "query_result" do
        expect_query_result(:tags, 2, :tag_count)
        expect_result_resources_to_include_data("resources", "name" => :tag_paths)
      end
    end

    context "assigns a tag to a Data Store without appropriate role" do
      before do
        api_basic_authorize

        run_post(ds_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "assigns a tag to a Data Store" do
      before do
        api_basic_authorize subcollection_action_identifier(:data_stores, :tags, :assign)

        run_post(ds_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(ds_url))
      end
    end

    context "unassigns a tag from a Data Store without appropriate role" do
      before do
        api_basic_authorize

        run_post(ds_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "unassigns a tag from a Data Store" do
      before do
        api_basic_authorize subcollection_action_identifier(:data_stores, :tags, :unassign)
        classify_resource(ds)

        run_post(ds_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(ds_url))
        verify_resource_has_single_tag_left(ds)
      end
    end
  end

  context "Resource Pool Tag subcollection" do
    let(:rp)          { FactoryGirl.create(:resource_pool, :name => "Resource Pool 1") }
    let(:rp_url)      { resource_pools_url(rp.id) }
    let(:rp_tags_url) { "#{rp_url}/tags" }

    context "query all tags of a Resource Pool and verify tag category and names" do
      before do
        api_basic_authorize
        classify_resource(rp)

        run_get "#{rp_tags_url}?expand=resources"
      end

      it "query_result" do
        expect_query_result(:tags, 2, :tag_count)
        expect_result_resources_to_include_data("resources", "name" => :tag_paths)
      end
    end

    context "assigns a tag to a Resource Pool without appropriate role" do
      before do
        api_basic_authorize

        run_post(rp_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "assigns a tag to a Resource Pool" do
      before do
        api_basic_authorize subcollection_action_identifier(:resource_pools, :tags, :assign)

        run_post(rp_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(rp_url))
      end
    end

    context "unassigns a tag from a Resource Pool without appropriate role" do
      before do
        api_basic_authorize

        run_post(rp_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "unassigns a tag from a Resource Pool" do
      before do
        api_basic_authorize subcollection_action_identifier(:resource_pools, :tags, :unassign)
        classify_resource(rp)

        run_post(rp_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(rp_url))
        verify_resource_has_single_tag_left(rp)
      end
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

    context "query all tags of a Cluster and verify tag category and names" do
      before do
        api_basic_authorize
        classify_resource(cluster)

        run_get "#{cluster_tags_url}?expand=resources"
      end

      it "query_result" do
        expect_query_result(:tags, 2, :tag_count)
        expect_result_resources_to_include_data("resources", "name" => :tag_paths)
      end
    end

    context "assigns a tag to a Cluster without appropriate role" do
      before do
        api_basic_authorize

        run_post(cluster_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "assigns a tag to a Cluster" do
      before do
        api_basic_authorize subcollection_action_identifier(:clusters, :tags, :assign)

        run_post(cluster_tags_url, gen_request(:assign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(cluster_url))
      end
    end

    context "unassigns a tag from a Cluster without appropriate role" do
      before do
        api_basic_authorize

        run_post(cluster_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "unassigns a tag from a Cluster" do
      let(:tag_results)  { tag1_results(cluster_url) }
      let(:verify_model) { verify_resource_has_single_tag_left(cluster) }

      before do
        api_basic_authorize subcollection_action_identifier(:clusters, :tags, :unassign)
        classify_resource(cluster)

        run_post(cluster_tags_url, gen_request(:unassign, :category => tag1[:category], :name => tag1[:name]))
      end

      it "tagging_result" do
        expect_tagging_result(tag1_results(cluster_url))
        verify_resource_has_single_tag_left(cluster)
      end
    end
  end
end
