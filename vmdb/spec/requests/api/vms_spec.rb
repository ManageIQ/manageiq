#
# REST API Request Tests - /api/vms
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

  def gen_request(action, *hrefs)
    request = {"action" => action.to_s}
    request["resources"] = hrefs.collect { |href| {"href" => href} } if hrefs.present?
    request
  end

  context "Vm accounts subcollection" do
    it "query VM accounts subcollection with no related accounts" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)

      @success = run_get "#{@cfme[:vms_url]}/#{vm.id}/accounts"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("accounts")
      expect(@result["resources"]).to be_empty
    end

    it "query VM accounts subcollection with two related accounts" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      acct1 = FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "John")
      acct2 = FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "Jane")

      vm_accounts_url = "#{@cfme[:vms_url]}/#{vm.id}/accounts"
      @success = run_get vm_accounts_url

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("accounts")
      expect(@result["subcount"]).to eq(2)
      expect(@result["resources"].size).to eq(2)
      expect(resources_include_suffix?(@result["resources"], "href", "#{vm_accounts_url}/#{acct1.id}")).to be_true
      expect(resources_include_suffix?(@result["resources"], "href", "#{vm_accounts_url}/#{acct2.id}")).to be_true
    end

    it "query VM accounts subcollection with a valid Account Id" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      acct1 = FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "John")

      @success = run_get "#{@cfme[:vms_url]}/#{vm.id}/accounts/#{acct1.id}"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("John")
    end

    it "query VM accounts subcollection with an invalid Account Id" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "John")

      @success = run_get "#{@cfme[:vms_url]}/#{vm.id}/accounts/9999"

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "query VM accounts subcollection with two related accounts using expand directive" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm_accounts_url = "#{vm_url}/accounts"
      acct1 = FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "John")
      acct2 = FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "Jane")

      @success = run_get "#{vm_url}?expand=accounts"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("accounts")
      expect(@result["accounts"].size).to eq(2)
      expect(resources_include_suffix?(@result["accounts"], "id", "#{vm_accounts_url}/#{acct1.id}")).to be_true
      expect(resources_include_suffix?(@result["accounts"], "id", "#{vm_accounts_url}/#{acct2.id}")).to be_true
    end
  end

  context "Vm software subcollection" do
    it "query VM software subcollection with no related software" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)

      @success = run_get "#{@cfme[:vms_url]}/#{vm.id}/software"

      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("software")
      expect(@result["resources"]).to be_empty
    end

    it "query VM software subcollection with two related software" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      sw1 = FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Word")
      sw2 = FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Excel")
      vm_software_url = "#{@cfme[:vms_url]}/#{vm.id}/software"

      @success = run_get vm_software_url

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("software")
      expect(@result["subcount"]).to eq(2)
      expect(@result["resources"].size).to eq(2)
      expect(resources_include_suffix?(@result["resources"], "href", "#{vm_software_url}/#{sw1.id}")).to be_true
      expect(resources_include_suffix?(@result["resources"], "href", "#{vm_software_url}/#{sw2.id}")).to be_true
    end

    it "query VM software subcollection with a valid Software Id" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      sw1 = FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Word")

      @success = run_get "#{@cfme[:vms_url]}/#{vm.id}/software/#{sw1.id}"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("Word")
    end

    it "query VM software subcollection with an invalid Software Id" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Word")

      @success = run_get "#{@cfme[:vms_url]}/#{vm.id}/software/9999"

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "query VM software subcollection with two related software using expand directive" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm_software_url = "#{vm_url}/software"
      sw1 = FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Word")
      sw2 = FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Excel")

      @success = run_get "#{vm_url}?expand=software"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("software")
      expect(@result["software"].size).to eq(2)
      expect(resources_include_suffix?(@result["software"], "id", "#{vm_software_url}/#{sw1.id}")).to be_true
      expect(resources_include_suffix?(@result["software"], "id", "#{vm_software_url}/#{sw2.id}")).to be_true
    end
  end

  context "Vm start action" do
    it "starts an invalid vm" do
      update_user_role(@role, action_identifier(:vms, :start))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request(:start))

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "starts an invalid vm without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request(:start))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "starts a powered on vm" do
      update_user_role(@role, action_identifier(:vms, :start))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :power_state => "on")
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:start))

      expect(@result).to have_key("success")
      expect(@result["success"]).to be_false
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("is powered on")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
    end

    it "starts a vm" do
      update_user_role(@role, action_identifier(:vms, :start))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :power_state => "off")
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:start))

      expect(@result).to have_key("success")
      expect(@result["success"]).to be_true
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("starting")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
      expect(@result).to have_key("task_id")
      expect(@result).to have_key("task_href")
    end

    it "starts multiple vms" do
      update_user_role(@role, action_identifier(:vms, :start))
      basic_authorize @cfme[:user], @cfme[:password]

      vm1 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :power_state => "off")
      vm2 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :power_state => "off")

      vm1_url = "#{@cfme[:vms_url]}/#{vm1.id}"
      vm2_url = "#{@cfme[:vms_url]}/#{vm2.id}"

      @success = run_post(@cfme[:vms_url], gen_request(:start, vm1_url, vm2_url))

      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(2)
      expect(resources_include_suffix?(results, "href", "#{vm1_url}")).to be_true
      expect(resources_include_suffix?(results, "href", "#{vm2_url}")).to be_true
      expect(results.all? { |r| r["success"] }).to be_true
      expect(results.all? { |r| r.key?("task_id") }).to be_true
      expect(results.all? { |r| r.key?("task_href") }).to be_true
    end
  end

  context "Vm stop action" do
    it "stops an invalid vm" do
      update_user_role(@role, action_identifier(:vms, :stop))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request(:stop))

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "stops an invalid vm without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request(:stop))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "stops a powered off vm" do
      update_user_role(@role, action_identifier(:vms, :stop))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :power_state => "off")
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:stop))

      expect(@result).to have_key("success")
      expect(@result["success"]).to be_false
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("is not powered on")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
    end

    it "stops a vm" do
      update_user_role(@role, action_identifier(:vms, :stop))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :power_state => "on")
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:stop))

      expect(@result).to have_key("success")
      expect(@result["success"]).to be_true
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("stopping")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
      expect(@result).to have_key("task_id")
      expect(@result).to have_key("task_href")
    end

    it "stops multiple vms" do
      update_user_role(@role, action_identifier(:vms, :stop))
      basic_authorize @cfme[:user], @cfme[:password]

      vm1 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :power_state => "on")
      vm2 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :power_state => "on")

      vm1_url = "#{@cfme[:vms_url]}/#{vm1.id}"
      vm2_url = "#{@cfme[:vms_url]}/#{vm2.id}"

      @success = run_post(@cfme[:vms_url], gen_request(:stop, vm1_url, vm2_url))

      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(2)
      expect(resources_include_suffix?(results, "href", "#{vm1_url}")).to be_true
      expect(resources_include_suffix?(results, "href", "#{vm2_url}")).to be_true
      expect(results.all? { |r| r["success"] }).to be_true
      expect(results.all? { |r| r.key?("task_id") }).to be_true
      expect(results.all? { |r| r.key?("task_href") }).to be_true
    end
  end
end
