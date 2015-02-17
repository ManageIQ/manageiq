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

  def gen_requests(action, data)
    request = {"action" => action.to_s}
    request["resources"] = data
    request
  end

  def gen_request_data(action, data, *hrefs)
    request = {"action" => action.to_s}
    if hrefs.present?
      request["resources"] = hrefs.collect { |href| data.dup.merge("href" => href) }
    else
      request["resource"] = data
    end
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

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")
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

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOff")
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

      vm1 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOff")
      vm2 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOff")

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

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOff")
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

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")
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

      vm1 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")
      vm2 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")

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

  context "Vm suspend action" do
    it "suspends an invalid vm" do
      update_user_role(@role, action_identifier(:vms, :suspend))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request(:suspend))

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "suspends an invalid vm without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request(:suspend))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "suspends a powered off vm" do
      update_user_role(@role, action_identifier(:vms, :suspend))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOff")
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:suspend))

      expect(@result).to have_key("success")
      expect(@result["success"]).to be_false
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("is not powered on")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
    end

    it "suspends a suspended vm" do
      update_user_role(@role, action_identifier(:vms, :suspend))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "suspended")
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:suspend))

      expect(@result).to have_key("success")
      expect(@result["success"]).to be_false
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("is not powered on")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
    end

    it "suspends a vm" do
      update_user_role(@role, action_identifier(:vms, :suspend))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:suspend))

      expect(@result).to have_key("success")
      expect(@result["success"]).to be_true
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("suspending")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
      expect(@result).to have_key("task_id")
      expect(@result).to have_key("task_href")
    end

    it "suspends multiple vms" do
      update_user_role(@role, action_identifier(:vms, :suspend))
      basic_authorize @cfme[:user], @cfme[:password]

      vm1 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")
      vm2 = FactoryGirl.create(:vm_vmware, :host => @host, :ems_id => @ems.id, :raw_power_state => "poweredOn")

      vm1_url = "#{@cfme[:vms_url]}/#{vm1.id}"
      vm2_url = "#{@cfme[:vms_url]}/#{vm2.id}"

      @success = run_post(@cfme[:vms_url], gen_request(:suspend, vm1_url, vm2_url))

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

  context "Vm delete action" do
    it "deletes an invalid vm" do
      update_user_role(@role, action_identifier(:vms, :delete))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request(:delete))

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "deletes a vm via a resource POST without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request(:delete))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "deletes a vm via a resource DELETE without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_delete("#{@cfme[:vms_url]}/999999")

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "deletes a vm via a resource POST" do
      update_user_role(@role, action_identifier(:vms, :delete))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:delete))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("success")
      expect(@result["success"]).to be_true
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("deleting")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
      expect(@result).to have_key("task_id")
      expect(@result).to have_key("task_href")
    end

    it "deletes a vm via a resource DELETE" do
      update_user_role(@role, action_identifier(:vms, :delete))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_delete(vm_url)

      expect(@success).to be_true
      expect(@code).to eq(204)
    end

    it "deletes multiple vms" do
      update_user_role(@role, action_identifier(:vms, :delete))
      basic_authorize @cfme[:user], @cfme[:password]

      vm1 = FactoryGirl.create(:vm_vmware)
      vm2 = FactoryGirl.create(:vm_vmware)

      vm1_url = "#{@cfme[:vms_url]}/#{vm1.id}"
      vm2_url = "#{@cfme[:vms_url]}/#{vm2.id}"

      @success = run_post(@cfme[:vms_url], gen_request(:delete, vm1_url, vm2_url))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(2)
      expect(results.all? { |r| r["success"] }).to be_true
      expect(results.all? { |r| r.key?("task_id") }).to be_true
      expect(results.all? { |r| r.key?("task_href") }).to be_true
    end
  end

  context "Vm set_owner action" do
    it "set_owner to an invalid vm" do
      update_user_role(@role, action_identifier(:vms, :set_owner))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request_data(:set_owner, "owner" => "admin"))

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "set_owner without appropriate action role" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request_data(:set_owner, "owner" => "admin"))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "set_owner with missing owner" do
      update_user_role(@role, action_identifier(:vms, :set_owner))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request(:set_owner))

      expect(@success).to be_false
      expect(@code).to eq(400)
      expect(@result).to have_key("error")
      expect(@result["error"]["message"]).to match("Must specify an owner")
    end

    it "set_owner with invalid owner" do
      update_user_role(@role, action_identifier(:vms, :set_owner))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request_data(:set_owner, "owner" => "bad_user"))

      expect(@success).to be_true
      expect(@result).to have_key("success")
      expect(@result["success"]).to be_false
      expect(@result).to have_key("message")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
    end

    it "set_owner to a vm" do
      update_user_role(@role, action_identifier(:vms, :set_owner))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_post(vm_url, gen_request_data(:set_owner, "owner" => @cfme[:user]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("success")
      expect(@result["success"]).to be_true
      expect(@result).to have_key("message")
      expect(@result["message"]).to match("setting owner")
      expect(@result).to have_key("href")
      expect(@result["href"]).to match(vm_url)
      expect(vm.reload.evm_owner).to eq(@user)
    end

    it "set_owner to multiple vms" do
      update_user_role(@role, action_identifier(:vms, :set_owner))
      basic_authorize @cfme[:user], @cfme[:password]

      vm1 = FactoryGirl.create(:vm_vmware)
      vm2 = FactoryGirl.create(:vm_vmware)

      vm1_url = "#{@cfme[:vms_url]}/#{vm1.id}"
      vm2_url = "#{@cfme[:vms_url]}/#{vm2.id}"

      @success = run_post(@cfme[:vms_url], gen_request_data(:set_owner, {"owner" => @cfme[:user]}, vm1_url, vm2_url))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(2)
      expect(results.all? { |r| r["success"] }).to be_true
      expect(resources_include_suffix?(results, "href", "#{vm1_url}")).to be_true
      expect(resources_include_suffix?(results, "href", "#{vm2_url}")).to be_true
      expect(vm1.reload.evm_owner).to eq(@user)
      expect(vm2.reload.evm_owner).to eq(@user)
    end
  end

  context "Vm custom_attributes" do
    it "getting custom_attributes from a vm with no custom_attributes" do
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"

      @success = run_get("#{vm_url}/custom_attributes")

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("custom_attributes")
      expect(@result).to have_key("resources")
      expect(@result["resources"].size).to eq(0)
    end

    it "getting custom_attributes from a vm" do
      basic_authorize @cfme[:user], @cfme[:password]

      ca1 = FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1")
      ca2 = FactoryGirl.create(:custom_attribute, :name => "name2", :value => "value2")

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm_ca_url = "#{vm_url}/custom_attributes"
      vm.custom_attributes = [ca1, ca2]

      @success = run_get "#{vm_url}/custom_attributes"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("custom_attributes")
      expect(@result).to have_key("resources")
      expect(@result["resources"].size).to eq(2)
      expect(resources_include_suffix?(@result["resources"], "href", "#{vm_ca_url}/#{ca1.id}")).to be_true
      expect(resources_include_suffix?(@result["resources"], "href", "#{vm_ca_url}/#{ca2.id}")).to be_true
    end

    it "getting custom_attributes from a vm in expanded form" do
      basic_authorize @cfme[:user], @cfme[:password]

      ca1 = FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1")
      ca2 = FactoryGirl.create(:custom_attribute, :name => "name2", :value => "value2")

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm.custom_attributes = [ca1, ca2]

      @success = run_get "#{vm_url}/custom_attributes?expand=resources"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("name")
      expect(@result["name"]).to eq("custom_attributes")
      expect(@result).to have_key("resources")
      expect(@result["resources"].size).to eq(2)
      expect(@result["resources"].collect { |r| r["name"] }.sort).to eq(%w(name1 name2))
    end

    it "getting custom_attributes from a vm using expand" do
      basic_authorize @cfme[:user], @cfme[:password]

      ca1 = FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1")
      ca2 = FactoryGirl.create(:custom_attribute, :name => "name2", :value => "value2")

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm.custom_attributes = [ca1, ca2]

      @success = run_get "#{vm_url}?expand=custom_attributes"

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("custom_attributes")
      expect(@result["custom_attributes"].size).to eq(2)
      expect(@result["custom_attributes"].collect { |r| r["name"] }.sort).to eq(%w(name1 name2))
    end

    it "delete a custom_attribute without appropriate role" do
      basic_authorize @cfme[:user], @cfme[:password]

      ca1 = FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1")

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm.custom_attributes = [ca1]

      @success = run_post("#{vm_url}/custom_attributes", gen_request(:delete, vm_url))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "delete a custom_attribute from a vm via the delete action" do
      update_user_role(@role, action_identifier(:vms, :edit))
      basic_authorize @cfme[:user], @cfme[:password]

      ca1 = FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1")

      vm = FactoryGirl.create(:vm_vmware)
      vm_ca_url = "#{@cfme[:vms_url]}/#{vm.id}/custom_attributes"
      vm.custom_attributes = [ca1]

      @success = run_post(vm_ca_url, gen_request(:delete, "#{vm_ca_url}/#{ca1.id}"))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(vm.reload.custom_attributes).to be_empty
    end

    it "add custom attribute to a vm without a name" do
      update_user_role(@role, action_identifier(:vms, :edit))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_ca_url = "#{@cfme[:vms_url]}/#{vm.id}/custom_attributes"

      @success = run_post(vm_ca_url, gen_request_data(:add, "value" => "value1"))

      expect(@success).to be_false
      expect(@code).to eq(400)
      expect(@result).to have_key("error")
      expect(@result["error"]["message"]).to match("Must specify a name")
    end

    it "add custom attributes to a vm" do
      update_user_role(@role, action_identifier(:vms, :edit))
      basic_authorize @cfme[:user], @cfme[:password]

      vm = FactoryGirl.create(:vm_vmware)
      vm_ca_url = "#{@cfme[:vms_url]}/#{vm.id}/custom_attributes"

      @success = run_post(vm_ca_url, gen_requests(:add, [{"name" => "name1", "value" => "value1"},
                                                         {"name" => "name2", "value" => "value2"}]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      expect(@result["results"].collect { |r| r["name"] }.sort).to eq(%w(name1 name2))
      expect(vm.custom_attributes.size).to eq(2)
      expect(vm.custom_attributes.pluck(:value).sort).to eq(%w(value1 value2))
    end

    it "edit a custom attribute by name" do
      update_user_role(@role, action_identifier(:vms, :edit))
      basic_authorize @cfme[:user], @cfme[:password]

      ca1 = FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1")

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm_ca_url = "#{vm_url}/custom_attributes"
      vm.custom_attributes = [ca1]

      @success = run_post(vm_ca_url, gen_request_data(:edit, "name" => "name1", "value" => "value one"))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      expect(@result["results"].first["value"]).to eq("value one")
      expect(vm.reload.custom_attributes.first.value).to eq("value one")
    end

    it "edit a custom attribute by href" do
      update_user_role(@role, action_identifier(:vms, :edit))
      basic_authorize @cfme[:user], @cfme[:password]

      ca1 = FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1")

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm_ca_url = "#{vm_url}/custom_attributes"
      vm_ca1_url = "#{vm_ca_url}/#{ca1.id}"
      vm.custom_attributes = [ca1]

      @success = run_post(vm_ca_url, gen_request_data(:edit, "href" => vm_ca1_url, "value" => "new value1"))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      expect(@result["results"].first["value"]).to eq("new value1")
      expect(vm.reload.custom_attributes.first.value).to eq("new value1")
    end

    it "edit multiple custom attributes" do
      update_user_role(@role, action_identifier(:vms, :edit))
      basic_authorize @cfme[:user], @cfme[:password]

      ca1 = FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1")
      ca2 = FactoryGirl.create(:custom_attribute, :name => "name2", :value => "value2")

      vm = FactoryGirl.create(:vm_vmware)
      vm_url = "#{@cfme[:vms_url]}/#{vm.id}"
      vm_ca_url = "#{vm_url}/custom_attributes"
      vm.custom_attributes = [ca1, ca2]

      @success = run_post(vm_ca_url, gen_requests(:edit, [{"name" => "name1", "value" => "new value1"},
                                                          {"name" => "name2", "value" => "new value2"}]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      expect(@result["results"].first["value"]).to eq("new value1")
      expect(@result["results"].second["value"]).to eq("new value2")
      expect(vm.reload.custom_attributes.pluck(:value).sort).to eq(["new value1", "new value2"])
    end
  end

  context "Vm add_lifecycle_event action" do
    before(:each) do
      @vm = FactoryGirl.create(:vm_vmware)
      @vm_url = "#{@cfme[:vms_url]}/#{@vm.id}"

      @events = 1.upto(3).collect do |n|
        {:event => "event#{n}", :status => "status#{n}", :message => "message#{n}", :created_by => "system"}
      end
    end

    it "add_lifecycle_event to an invalid vm" do
      update_user_role(@role, action_identifier(:vms, :add_lifecycle_event))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post("#{@cfme[:vms_url]}/999999", gen_request_data(:add_lifecycle_event, :event => "event 1"))

      expect(@success).to be_false
      expect(@code).to eq(404)
    end

    it "add_lifecycle_event without appropriate action role" do
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm_url, gen_request_data(:add_lifecycle_event, :event => "event 1"))

      expect(@success).to be_false
      expect(@code).to eq(403)
    end

    it "add_lifecycle_event to a vm" do
      update_user_role(@role, action_identifier(:vms, :add_lifecycle_event))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@vm_url, gen_request_data(:add_lifecycle_event, @events[0]))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result["success"]).to be_true
      expect(@result["message"]).to match(/adding lifecycle event/i)
      expect(@result["href"]).to match(@vm_url)
      expect(@vm.lifecycle_events.size).to eq(1)
      expect(@vm.lifecycle_events.first.event).to eq(@events[0][:event])
    end

    it "add_lifecycle_event to multiple vms" do
      update_user_role(@role, action_identifier(:vms, :add_lifecycle_event))
      basic_authorize @cfme[:user], @cfme[:password]

      @success = run_post(@cfme[:vms_url], gen_requests(:add_lifecycle_event,
                                                        @events.collect { |e| {:href => @vm_url}.merge(e) }))

      expect(@success).to be_true
      expect(@code).to eq(200)
      expect(@result).to have_key("results")
      results = @result["results"]
      expect(results.size).to eq(@events.size)
      expect(results.all? { |r| r["success"] }).to be_true
      expect(@vm.lifecycle_events.size).to eq(@events.size)
      expect(@vm.lifecycle_events.collect(&:event)).to match_array(@events.collect { |e| e[:event] })
    end
  end
end
