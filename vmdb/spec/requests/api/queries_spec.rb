#
# REST API Request Tests - Queries
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
  end

  def app
    Vmdb::Application
  end

  def create_vms(count)
    count.times { FactoryGirl.create(:vm_vmware) }
  end

  context "Query collections" do
    it "to return resource lists with only hrefs" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_vms(3)

      @success = run_get @cfme[:vms_url]

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("vms")
      results = @result["resources"]
      expect(results.size).to eq(3)
      expect(results.all? do |result|
               result.keys == ["href"] && result["href"].match(%r{^http://.*/api/vms/[0-9]+$})
             end).to be_true
    end

    it "to return seperate ids and href when expanded" do
      basic_authorize @cfme[:user], @cfme[:password]

      create_vms(3)

      @success = run_get "#{@cfme[:vms_url]}?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("vms")
      results = @result["resources"]
      expect(results.size).to eq(3)
      expect(results.all? { |result| result["id"].kind_of?(Integer) }).to be_true
      expect(results.all? { |result| result["href"].match(%r{^http://.*/api/vms/[0-9]+$}) }).to be_true
      expect(results.all? { |result| result.key?("guid") }).to be_true
    end

    it "to always return ids and href when asking for specific attributes" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_get "#{@cfme[:vms_url]}?expand=resources&attributes=guid"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("vms")
      expect(@result).to have_key("resources")
      expect(@result["resources"].size).to eq(1)
      result = @result["resources"].first
      expect(result["id"]).to eq(vm.id)
      expect(result["href"]).to match(vm_url)
      expect(result["guid"]).to eq(vm.guid)
    end
  end

  context "Query resource" do
    it "to return both id and href" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_get vm_url

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["id"]).to eq(vm.id)
      expect(@result["href"]).to match(vm_url)
      expect(@result["guid"]).to eq(vm.guid)
    end
  end

  context "Query subcollections" do
    before(:each) do
      @vm = FactoryGirl.create(:vm_vmware)
      @vm_url = "#{@cfme[:vms_url]}/#{@vm.id}"
      @vm_accounts_url = "#{@vm_url}/accounts"
      @acct1 = FactoryGirl.create(:account, :vm_or_template_id => @vm.id, :name => "John")
      @acct2 = FactoryGirl.create(:account, :vm_or_template_id => @vm.id, :name => "Jane")
    end

    it "to return just href when not expanded" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@vm_url}/accounts"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("accounts")
      results = @result["resources"]
      expect(results.size).to eq(2)
      expect(results.all? { |result| result.keys == ["href"] }).to be_true
      expect(resources_include_suffix?(results, "href", "#{@vm_accounts_url}/#{@acct1.id}")).to be_true
      expect(resources_include_suffix?(results, "href", "#{@vm_accounts_url}/#{@acct2.id}")).to be_true
    end

    it "to include both id and href when getting a single resource" do
      basic_authorize @cfme[:user], @cfme[:password]

      acct1_url = "#{@vm_url}/accounts/#{@acct1.id}"
      @success = run_get acct1_url

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["id"]).to eq(@acct1.id)
      expect(@result["href"]).to match(acct1_url)
      expect(@result["name"]).to eq(@acct1.name)
    end

    it "to include both id and href when expanded" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_get "#{@vm_url}/accounts?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["name"]).to eq("accounts")
      results = @result["resources"]
      expect(results.size).to eq(2)
      expect(results.all? { |result| result.key?("href") && result.key?("id") }).to be_true
      expect(resources_include_suffix?(results, "href", "#{@vm_accounts_url}/#{@acct1.id}")).to be_true
      expect(resources_include_suffix?(results, "href", "#{@vm_accounts_url}/#{@acct2.id}")).to be_true
      expect(results.collect { |r| r["id"] }).to match_array([@acct1.id, @acct2.id])
    end
  end
end
