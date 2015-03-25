#
# REST API Request Tests - Queries
#
require 'spec_helper'

describe ApiController do
  include Rack::Test::Methods

  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)        { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)       { FactoryGirl.create(:host) }

  let(:vm1)        { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm1_url)    { vms_url(vm1.id) }

  let(:vm_href_pattern) { %r{^http://.*/api/vms/[0-9]+$} }

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  def create_vms(count)
    count.times { FactoryGirl.create(:vm_vmware) }
  end

  context "Query collections" do
    it "to return resource lists with only hrefs" do
      api_basic_authorize
      create_vms(3)

      run_get vms_url

      expect_query_result(:vms, 3, 3)
      expect_result_resources_to_have_only_keys("resources", %w(href))
      expect_result_resource_keys_to_match_pattern("resources", "href", :vm_href_pattern)
    end

    it "to return seperate ids and href when expanded" do
      api_basic_authorize
      create_vms(3)

      run_get vms_url, :expand => "resources"

      expect_query_result(:vms, 3, 3)
      expect_result_resource_keys_to_match_pattern("resources", "href", :vm_href_pattern)
      expect_result_resource_keys_to_be_like_klass("resources", "id", Integer)
      expect_result_resources_to_include_keys("resources", %w(guid))
    end

    it "to always return ids and href when asking for specific attributes" do
      api_basic_authorize
      vm1   # create resource

      run_get vms_url, :expand => "resources", :attributes => "guid"

      expect_query_result(:vms, 1, 1)
      expect_result_resources_to_match_hash([{"id" => vm1.id, "href" => vm1_url, "guid" => vm1.guid}])
    end
  end

  context "Query resource" do
    it "to return both id and href" do
      api_basic_authorize
      vm1   # create resource

      run_get vm1_url

      expect_single_resource_query("id" => vm1.id, "href" => vm1_url, "guid" => vm1.guid)
    end
  end

  context "Query subcollections" do
    let(:acct1) { FactoryGirl.create(:account, :vm_or_template_id => vm1.id, :name => "John") }
    let(:acct2) { FactoryGirl.create(:account, :vm_or_template_id => vm1.id, :name => "Jane") }
    let(:vm1_accounts_url) { "#{vm1_url}/accounts" }
    let(:acct1_url)        { "#{vm1_accounts_url}/#{acct1.id}" }
    let(:acct2_url)        { "#{vm1_accounts_url}/#{acct2.id}" }
    let(:vm1_accounts_url_list) { [acct1_url, acct2_url] }

    it "to return just href when not expanded" do
      api_basic_authorize
      # create resources
      acct1
      acct2

      run_get vm1_accounts_url

      expect_query_result(:accounts, 2)
      expect_result_resources_to_include_hrefs("resources", :vm1_accounts_url_list)
    end

    it "to include both id and href when getting a single resource" do
      api_basic_authorize

      run_get acct1_url

      expect_single_resource_query("id" => acct1.id, "href" => acct1_url, "name" => acct1.name)
    end

    it "to include both id and href when expanded" do
      api_basic_authorize
      # create resources
      acct1
      acct2

      run_get vm1_accounts_url, :expand => "resources"

      expect_query_result(:accounts, 2)
      expect_result_resources_to_include_keys("resources", %w(id href))
      expect_result_resources_to_include_hrefs("resources", :vm1_accounts_url_list)
      expect_result_resources_to_include_data("resources", "id" => [acct1.id, acct2.id])
    end
  end
end
