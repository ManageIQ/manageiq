#
# REST API Request Tests - /api/vms
#
require 'spec_helper'

describe ApiController do

  include Rack::Test::Methods

  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)        { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)       { FactoryGirl.create(:host) }

  let(:vm)         { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm1)        { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm2)        { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm1_url)    { vms_url(vm1.id) }
  let(:vm2_url)    { vms_url(vm2.id) }
  let(:vms_list)   { [vm1_url, vm2_url] }
  let(:vm_guid)    { vm.guid }
  let(:vm_url)     { vms_url(vm.id) }

  let(:invalid_vm_url) { vms_url(999_999) }

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  context "Vm accounts subcollection" do
    let(:acct1) { FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "John") }
    let(:acct2) { FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "Jane") }
    let(:vm_accounts_url)      { "#{vms_url(vm.id)}/accounts" }
    let(:acct1_url)            { "#{vm_accounts_url}/#{acct1.id}" }
    let(:acct2_url)            { "#{vm_accounts_url}/#{acct2.id}" }
    let(:vm_accounts_url_list) { [acct1_url, acct2_url] }

    context "query VM accounts subcollection with no related accounts" do
      before do
        api_basic_authorize

        run_get vm_accounts_url
      end

      it "empty_query_result" do
        expect_empty_query_result(:accounts)
      end
    end

    context "query VM accounts subcollection with two related accounts" do
      before do
        api_basic_authorize
        # create resources
        acct1
        acct2

        run_get vm_accounts_url
      end

      it "query_result" do
        expect_query_result(:accounts, 2)
        expect_result_resources_to_include_hrefs("resources", :vm_accounts_url_list)
      end
    end

    context "query VM accounts subcollection with a valid Account Id" do
      before do
        api_basic_authorize

        run_get acct1_url
      end

      it "single_resource_query" do
        expect_single_resource_query("name" => "John")
      end
    end

    context "query VM accounts subcollection with an invalid Account Id" do
      before do
        api_basic_authorize

        run_get "#{vm_accounts_url}/999999"
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "query VM accounts subcollection with two related accounts using expand directive" do
      before do
        api_basic_authorize
        # create resources
        acct1
        acct2

        run_get "#{vm_url}?expand=accounts"
      end

      it "single_resource_query" do
        expect_single_resource_query("guid" => :vm_guid)
        expect_result_resources_to_include_hrefs("accounts", :vm_accounts_url_list)
      end
    end
  end

  context "Vm software subcollection" do
    let(:sw1) { FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Word")  }
    let(:sw2) { FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Excel") }
    let(:vm_software_url)      { "#{vms_url(vm.id)}/software"    }
    let(:sw1_url)              { "#{vm_software_url}/#{sw1.id}" }
    let(:sw2_url)              { "#{vm_software_url}/#{sw2.id}" }
    let(:vm_software_url_list) { [sw1_url, sw2_url] }

    context "query VM software subcollection with no related software" do
      before do
        api_basic_authorize

        run_get vm_software_url
      end

      it "empty_query_resource" do
        expect_empty_query_result(:software)
      end
    end

    context "query VM software subcollection with two related software" do
      before do
        api_basic_authorize
        # create resources
        sw1
        sw2

        run_get vm_software_url
      end

      it "query_result" do
        expect_query_result(:software, 2)
        expect_result_resources_to_include_hrefs("resources", :vm_software_url_list)
      end
    end

    context "query VM software subcollection with a valid Software Id" do
      before do
        api_basic_authorize

        run_get sw1_url
      end

      it "single_resource_query" do
        expect_single_resource_query("name" => "Word")
      end
    end

    context "query VM software subcollection with an invalid Software Id" do
      before do
        api_basic_authorize

        run_get "#{vm_software_url}/999999"
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "query VM software subcollection with two related software using expand directive" do
      before do
        api_basic_authorize
        # create resources
        sw1
        sw2

        run_get "#{vms_url(vm.id)}?expand=software"
      end

      it "single_resource_query" do
        expect_single_resource_query("guid" => :vm_guid)
        expect_result_resources_to_include_hrefs("software", :vm_software_url_list)
      end
    end
  end

  context "Vm start action" do
    context "starts an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :start)

        run_post(invalid_vm_url, gen_request(:start))
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "starts an invalid vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:start))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "starts a powered on vm" do
      before do
        api_basic_authorize action_identifier(:vms, :start)

        run_post(vm_url, gen_request(:start))
      end

      it "single_action_result" do
        expect_single_action_result(:success => false, :message => "is powered on", :href => :vm_url)
      end
    end

    context "starts a vm" do
      let(:vm)  { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }

      before do
        api_basic_authorize action_identifier(:vms, :start)

        run_post(vm_url, gen_request(:start))
      end

      it "single_action_result" do
        expect_single_action_result(:success => true, :message => "starting", :href => :vm_url, :task => true)
      end
    end

    context "starts multiple vms" do
      let(:vm1) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }
      let(:vm2) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }

      before do
        api_basic_authorize action_identifier(:vms, :start)

        run_post(vms_url, gen_request(:start, nil, vm1_url, vm2_url))
      end

      it "multiple_action_result" do
        expect_multiple_action_result(2, :task => true)
        expect_result_resources_to_include_hrefs("results", :vms_list)
      end
    end
  end

  context "Vm stop action" do
    context "stops an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :stop)

        run_post(invalid_vm_url, gen_request(:stop))
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "stops an invalid vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:stop))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "stops a powered off vm" do
      let(:vm)  { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }

      before do
        api_basic_authorize action_identifier(:vms, :stop)

        run_post(vm_url, gen_request(:stop))
      end

      it "single_action_result" do
        expect_single_action_result(:success => false, :message => "is not powered on", :href => :vm_url)
      end
    end

    context "stops a vm" do
      before do
        api_basic_authorize action_identifier(:vms, :stop)

        run_post(vm_url, gen_request(:stop))
      end

      it "single_action_result" do
        expect_single_action_result(:success => true, :message => "stopping", :href => :vm_url, :task => true)
      end
    end

    context "stops multiple vms" do
      before do
        api_basic_authorize action_identifier(:vms, :stop)

        run_post(vms_url, gen_request(:stop, nil, vm1_url, vm2_url))
      end

      it "multiple_action_result" do
        expect_multiple_action_result(2, :task => true)
        expect_result_resources_to_include_hrefs("results", :vms_list)
      end
    end
  end

  context "Vm suspend action" do
    context "suspends an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(invalid_vm_url, gen_request(:suspend))
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "suspends an invalid vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:suspend))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "suspends a powered off vm" do
      let(:vm) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }

      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(vm_url, gen_request(:suspend))
      end

      it "single_action_result" do
        expect_single_action_result(:success => false, :message => "is not powered on", :href => :vm_url)
      end
    end

    context "suspends a suspended vm" do
      let(:vm) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "suspended") }

      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(vm_url, gen_request(:suspend))
      end

      it "single_action_result" do
        expect_single_action_result(:success => false, :message => "is not powered on", :href => :vm_url)
      end
    end

    context "suspends a vm" do
      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(vm_url, gen_request(:suspend))
      end

      it "single_action_result" do
        expect_single_action_result(:success => true, :message => "suspending", :href => :vm_url, :task => true)
      end
    end

    context "suspends multiple vms" do
      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(vms_url, gen_request(:suspend, nil, vm1_url, vm2_url))
      end

      it "multiple_action_result" do
        expect_multiple_action_result(2, :task => true)
        expect_result_resources_to_include_hrefs("results", :vms_list)
      end
    end
  end

  context "Vm delete action" do
    context "deletes an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :delete)

        run_post(invalid_vm_url, gen_request(:delete))
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "deletes a vm via a resource POST without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:delete))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "deletes a vm via a resource DELETE without appropriate role" do
      before do
        api_basic_authorize

        run_delete(invalid_vm_url)
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "deletes a vm via a resource POST" do
      before do
        api_basic_authorize action_identifier(:vms, :delete)

        run_post(vm_url, gen_request(:delete))
      end

      it "single_action_result" do
        expect_single_action_result(:success => true, :message => "deleting", :href => :vm_url, :task => true)
      end
    end

    context "deletes a vm via a resource DELETE" do
      before do
        api_basic_authorize action_identifier(:vms, :delete)

        run_delete(vm_url)
      end

      it "request_success_with_no_content" do
        expect_request_success_with_no_content
      end
    end

    context "deletes multiple vms" do
      before do
        api_basic_authorize action_identifier(:vms, :delete)

        run_post(vms_url, gen_request(:delete, nil, vm1_url, vm2_url))
      end

      it "multiple_action_result" do
        expect_multiple_action_result(2, :task => true)
      end
    end
  end

  context "Vm set_owner action" do
    context "set_owner to an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(invalid_vm_url, gen_request(:set_owner, "owner" => "admin"))
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "set_owner without appropriate action role" do
      before do
        api_basic_authorize

        run_post(vm_url, gen_request(:set_owner, "owner" => "admin"))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "set_owner with missing owner" do
      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(vm_url, gen_request(:set_owner))
      end

      it "bad_request" do
        expect_bad_request("Must specify an owner")
      end
    end

    context "set_owner with invalid owner" do
      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(vm_url, gen_request(:set_owner, "owner" => "bad_user"))
      end

      it "single_action_result" do
        expect_single_action_result(:success => false, :message => /.*/, :href => :vm_url)
      end
    end

    context "set_owner to a vm" do
      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(vm_url, gen_request(:set_owner, "owner" => @cfme[:user]))
      end

      it "single_action_result" do
        expect_single_action_result(:success => true, :message => "setting owner", :href => :vm_url)
        expect(vm.reload.evm_owner).to eq(@user)
      end
    end

    context "set_owner to multiple vms" do
      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(vms_url, gen_request(:set_owner, {"owner" => @cfme[:user]}, vm1_url, vm2_url))
      end

      it "multiple_action_result" do
        expect_multiple_action_result(2)
        expect_result_resources_to_include_hrefs("results", :vms_list)
        expect(vm1.reload.evm_owner).to eq(@user)
        expect(vm2.reload.evm_owner).to eq(@user)
      end
    end
  end

  context "Vm custom_attributes" do
    let(:ca1) { FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1") }
    let(:ca2) { FactoryGirl.create(:custom_attribute, :name => "name2", :value => "value2") }
    let(:vm_ca_url)      { "#{vm_url}/custom_attributes" }
    let(:ca1_url)        { "#{vm_ca_url}/#{ca1.id}" }
    let(:ca2_url)        { "#{vm_ca_url}/#{ca2.id}" }
    let(:vm_ca_url_list) { [ca1_url, ca2_url] }

    context "getting custom_attributes from a vm with no custom_attributes" do
      before do
        api_basic_authorize

        run_get(vm_ca_url)
      end

      it "empty_query_result" do
        expect_empty_query_result(:custom_attributes)
      end
    end

    context "getting custom_attributes from a vm" do
      before do
        api_basic_authorize
        vm.custom_attributes = [ca1, ca2]

        run_get vm_ca_url
      end

      it "query_result" do
        expect_query_result(:custom_attributes, 2)
        expect_result_resources_to_include_hrefs("resources", :vm_ca_url_list)
      end
    end

    context "getting custom_attributes from a vm in expanded form" do
      before do
        api_basic_authorize
        vm.custom_attributes = [ca1, ca2]

        run_get "#{vm_ca_url}?expand=resources"
      end

      it "query_result" do
        expect_query_result(:custom_attributes, 2)
        expect_result_resources_to_include_data("resources", "name" => %w(name1 name2))
      end
    end

    context "getting custom_attributes from a vm using expand" do
      before do
        api_basic_authorize
        vm.custom_attributes = [ca1, ca2]

        run_get "#{vm_url}?expand=custom_attributes"
      end

      it "single_resource_query" do
        expect_single_resource_query("guid" => :vm_guid)
        expect_result_resources_to_include_data("custom_attributes", "name" => %w(name1 name2))
      end
    end

    context "delete a custom_attribute without appropriate role" do
      before do
        api_basic_authorize
        vm.custom_attributes = [ca1]

        run_post(vm_ca_url, gen_request(:delete, nil, vm_url))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "delete a custom_attribute from a vm via the delete action" do
      before do
        api_basic_authorize action_identifier(:vms, :edit)
        vm.custom_attributes = [ca1]

        run_post(vm_ca_url, gen_request(:delete, nil, ca1_url))
      end

      it "request_success" do
        expect_request_success
        expect(vm.reload.custom_attributes).to be_empty
      end
    end

    context "add custom attribute to a vm without a name" do
      before do
        api_basic_authorize action_identifier(:vms, :edit)

        run_post(vm_ca_url, gen_request(:add, "value" => "value1"))
      end

      it "bad_request" do
        expect_bad_request("Must specify a name")
      end
    end

    context "add custom attributes to a vm" do
      before do
        api_basic_authorize action_identifier(:vms, :edit)

        run_post(vm_ca_url, gen_request(:add, [{"name" => "name1", "value" => "value1"},
                                               {"name" => "name2", "value" => "value2"}]))
      end

      it "request_success" do
        expect_request_success
        expect_result_resources_to_include_data("results", "name" => %w(name1 name2))
        expect(vm.custom_attributes.size).to eq(2)
        expect(vm.custom_attributes.pluck(:value).sort).to eq(%w(value1 value2))
      end
    end

    context "edit a custom attribute by name" do
      before do
        api_basic_authorize action_identifier(:vms, :edit)
        vm.custom_attributes = [ca1]

        run_post(vm_ca_url, gen_request(:edit, "name" => "name1", "value" => "value one"))
      end

      it "request_success" do
        expect_request_success
        expect_result_resources_to_include_data("results", "value" => ["value one"])
        expect(vm.reload.custom_attributes.first.value).to eq("value one")
      end
    end

    context "edit a custom attribute by href" do
      before do
        api_basic_authorize action_identifier(:vms, :edit)
        vm.custom_attributes = [ca1]

        run_post(vm_ca_url, gen_request(:edit, "href" => ca1_url, "value" => "new value1"))
      end

      it "request_success" do
        expect_request_success
        expect_result_resources_to_include_data("results", "value" => ["new value1"])
        expect(vm.reload.custom_attributes.first.value).to eq("new value1")
      end
    end

    context "edit multiple custom attributes" do
      before do
        api_basic_authorize action_identifier(:vms, :edit)
        vm.custom_attributes = [ca1, ca2]

        run_post(vm_ca_url, gen_request(:edit, [{"name" => "name1", "value" => "new value1"},
                                                {"name" => "name2", "value" => "new value2"}]))
      end

      it "request_success" do
        expect_request_success
        expect_result_resources_to_include_data("results", "value" => ["new value1", "new value2"])
        expect(vm.reload.custom_attributes.pluck(:value).sort).to eq(["new value1", "new value2"])
      end
    end
  end

  context "Vm add_lifecycle_event action" do
    let(:events) do
      1.upto(3).collect do |n|
        {:event => "event#{n}", :status => "status#{n}", :message => "message#{n}", :created_by => "system"}
      end
    end

    context "add_lifecycle_event to an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :add_lifecycle_event)

        run_post(invalid_vm_url, gen_request(:add_lifecycle_event, :event => "event 1"))
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "add_lifecycle_event without appropriate action role" do
      before do
        api_basic_authorize

        run_post(vm_url, gen_request(:add_lifecycle_event, :event => "event 1"))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "add_lifecycle_event to a vm" do
      before do
        api_basic_authorize action_identifier(:vms, :add_lifecycle_event)

        run_post(vm_url, gen_request(:add_lifecycle_event, events[0]))
      end

      it "single_action_result" do
        expect_single_action_result(:success => true, :message => /adding lifecycle event/i, :href => :vm_url)
        expect(vm.lifecycle_events.size).to eq(1)
        expect(vm.lifecycle_events.first.event).to eq(events[0][:event])
      end
    end

    context "add_lifecycle_event to multiple vms" do
      before do
        api_basic_authorize action_identifier(:vms, :add_lifecycle_event)

        run_post(vms_url, gen_request(:add_lifecycle_event,
                                      events.collect { |e| {:href => vm_url}.merge(e) }))
      end

      it "multiple_action_result" do
        expect_multiple_action_result(3)
        expect(vm.lifecycle_events.size).to eq(events.size)
        expect(vm.lifecycle_events.collect(&:event)).to match_array(events.collect { |e| e[:event] })
      end
    end
  end

  context "Vm scan action" do
    context "scans an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :scan)

        run_post(invalid_vm_url, gen_request(:scan))
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "scans an invalid Vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:scan))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "scan a Vm" do
      before do
        api_basic_authorize action_identifier(:vms, :scan)

        run_post(vm_url, gen_request(:scan))
      end

      it "single_action_result" do
        expect_single_action_result(:success => true, :message => "scanning", :href => :vm_url, :task => true)
      end
    end

    context "scan multiple Vms" do
      before do
        api_basic_authorize action_identifier(:vms, :scan)

        run_post(vms_url, gen_request(:scan, nil, vm1_url, vm2_url))
      end

      it "multiple_action_result" do
        expect_multiple_action_result(2, :task => true)
        expect_result_resources_to_include_hrefs("results", :vms_list)
      end
    end
  end

  context "Vm add_event action" do
    context "to an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :add_event)

        run_post(invalid_vm_url, gen_request(:add_event))
      end

      it "resource_not_found" do
        expect_resource_not_found
      end
    end

    context "to an invalid vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:add_event))
      end

      it "request_forbidden" do
        expect_request_forbidden
      end
    end

    context "to a single Vm" do
      before do
        api_basic_authorize collection_action_identifier(:vms, :add_event)

        run_post(vm_url, gen_request(:add_event, :event_type => "special", :event_message => "message"))
      end

      it "single_action_result" do
        expect_single_action_result(:success => true, :message => /adding event/i, :href => :vm_url)
      end
    end

    context "to multiple Vms" do
      before do
        api_basic_authorize collection_action_identifier(:vms, :add_event)

        run_post(vms_url,
                 gen_request(:add_event,
                             [{"href" => vm1_url, "event_type" => "etype1", "event_message" => "emsg1"},
                              {"href" => vm2_url, "event_type" => "etype2", "event_message" => "emsg2"}]))
      end

      it "multiple_action_result" do
        expect_multiple_action_result(2)
        expect_result_resources_to_include_hrefs("results", :vms_list)
        expect_result_resources_to_match_key_data("results", "message",
                                                  [/adding event .*etype1/i, /adding event .*etype2/i])
      end
    end
  end
end
