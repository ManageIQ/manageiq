#
# REST API Request Tests - /api/vms
#
require 'spec_helper'
require 'requests/shared_examples/api'

describe ApiController do

  include Rack::Test::Methods

  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)        { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)       { FactoryGirl.create(:host) }

  let(:vm)         { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm1)        { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm2)        { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm1_url)    { vm_url(vm1.id) }
  let(:vm2_url)    { vm_url(vm2.id) }
  let(:vms_list)   { [vm1_url, vm2_url] }
  let(:vm_guid)    { vm.guid }
  let(:vm_href)    { vm_url(vm.id) }

  let(:invalid_vm_url) { vm_url(999_999) }

  before(:each) do
    init_api_spec_env
  end

  def app
    Vmdb::Application
  end

  context "Vm accounts subcollection" do
    let(:acct1) { FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "John") }
    let(:acct2) { FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "Jane") }
    let(:vm_accounts_url)      { "#{vm_url(vm.id)}/accounts" }
    let(:acct1_url)            { "#{vm_accounts_url}/#{acct1.id}" }
    let(:acct2_url)            { "#{vm_accounts_url}/#{acct2.id}" }
    let(:vm_accounts_url_list) { [acct1_url, acct2_url] }

    context "query VM accounts subcollection with no related accounts" do
      before do
        api_basic_authorize

        run_get vm_accounts_url
      end

      include_examples "empty_query_result", :accounts
    end

    context "query VM accounts subcollection with two related accounts" do
      before do
        api_basic_authorize
        acct1
        acct2

        run_get vm_accounts_url
      end

      include_examples "query_result", :accounts, 2, :includes_hrefs => ["resources", :vm_accounts_url_list]
    end

    context "query VM accounts subcollection with a valid Account Id" do
      before do
        api_basic_authorize
        acct1

        run_get acct1_url
      end

      include_examples "single_resource_query", "name" => "John"
    end

    context "query VM accounts subcollection with an invalid Account Id" do
      before do
        api_basic_authorize
        acct1

        run_get "#{vm_accounts_url}/999999"
      end

      include_examples "resource_not_found"
    end

    context "query VM accounts subcollection with two related accounts using expand directive" do
      before do
        api_basic_authorize
        acct1
        acct2

        run_get "#{vm_href}?expand=accounts"
      end

      include_examples "single_resource_query",
                       "guid"          => :vm_guid,
                       :includes_hrefs => ["accounts", :vm_accounts_url_list]
    end
  end

  context "Vm software subcollection" do
    let(:sw1) { FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Word")  }
    let(:sw2) { FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Excel") }
    let(:vm_software_url)      { "#{vm_url(vm.id)}/software"    }
    let(:sw1_url)              { "#{vm_software_url}/#{sw1.id}" }
    let(:sw2_url)              { "#{vm_software_url}/#{sw2.id}" }
    let(:vm_software_url_list) { [sw1_url, sw2_url] }

    context "query VM software subcollection with no related software" do
      before do
        api_basic_authorize

        run_get vm_software_url
      end

      include_examples "empty_query_result", :software
    end

    context "query VM software subcollection with two related software" do
      before do
        api_basic_authorize
        sw1
        sw2

        run_get vm_software_url
      end

      include_examples "query_result", :software, 2, :includes_hrefs => ["resources", :vm_software_url_list]
    end

    context "query VM software subcollection with a valid Software Id" do
      before do
        api_basic_authorize

        run_get sw1_url
      end

      include_examples "single_resource_query", "name" => "Word"
    end

    context "query VM software subcollection with an invalid Software Id" do
      before do
        api_basic_authorize
        sw1

        run_get "#{vm_software_url}/999999"
      end

      include_examples "resource_not_found"
    end

    context "query VM software subcollection with two related software using expand directive" do
      before do
        api_basic_authorize
        sw1
        sw2

        run_get "#{vm_url(vm.id)}?expand=software"
      end

      include_examples "single_resource_query",
                       "guid"          => :vm_guid,
                       :includes_hrefs => ["software", :vm_software_url_list]
    end
  end

  context "Vm start action" do
    context "starts an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :start)

        run_post(invalid_vm_url, gen_request(:start))
      end

      include_examples "resource_not_found"
    end

    context "starts an invalid vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:start))
      end

      include_examples "request_forbidden"
    end

    context "starts a powered on vm" do
      before do
        api_basic_authorize action_identifier(:vms, :start)

        run_post(vm_href, gen_request(:start))
      end

      include_examples "single_action", :success => false, :message => "is powered on", :href => :vm_href
    end

    context "starts a vm" do
      let(:vm)  { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }

      before do
        api_basic_authorize action_identifier(:vms, :start)

        run_post(vm_href, gen_request(:start))
      end

      include_examples "single_action", :success => true, :message => "starting", :href => :vm_href, :task => true
    end

    context "starts multiple vms" do
      let(:vm1) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }
      let(:vm2) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }

      before do
        api_basic_authorize action_identifier(:vms, :start)

        run_post(vms_url, gen_request(:start, nil, vm1_url, vm2_url))
      end

      include_examples "multiple_actions", 2, :href_list => :vms_list, :task => true
    end
  end

  context "Vm stop action" do
    context "stops an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :stop)

        run_post(invalid_vm_url, gen_request(:stop))
      end

      include_examples "resource_not_found"
    end

    context "stops an invalid vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:stop))
      end

      include_examples "request_forbidden"
    end

    context "stops a powered off vm" do
      let(:vm)  { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }

      before do
        api_basic_authorize action_identifier(:vms, :stop)

        run_post(vm_href, gen_request(:stop))
      end

      include_examples "single_action", :success => false, :message => "is not powered on", :href => :vm_href
    end

    context "stops a vm" do
      before do
        api_basic_authorize action_identifier(:vms, :stop)

        run_post(vm_href, gen_request(:stop))
      end

      include_examples "single_action", :success => true, :message => "stopping", :href => :vm_href, :task => true
    end

    context "stops multiple vms" do
      before do
        api_basic_authorize action_identifier(:vms, :stop)

        run_post(vms_url, gen_request(:stop, nil, vm1_url, vm2_url))
      end

      include_examples "multiple_actions", 2, :href_list => :vms_list, :task => true
    end
  end

  context "Vm suspend action" do
    context "suspends an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(invalid_vm_url, gen_request(:suspend))
      end

      include_examples "resource_not_found"
    end

    context "suspends an invalid vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:suspend))
      end

      include_examples "request_forbidden"
    end

    context "suspends a powered off vm" do
      let(:vm) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "poweredOff") }

      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(vm_href, gen_request(:suspend))
      end

      include_examples "single_action", :success => false, :message => "is not powered on", :href => :vm_href
    end

    context "suspends a suspended vm" do
      let(:vm) { FactoryGirl.create(:vm_vmware, :host => host, :ems_id => ems.id, :raw_power_state => "suspended") }

      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(vm_href, gen_request(:suspend))
      end

      include_examples "single_action", :success => false, :message => "is not powered on", :href => :vm_href
    end

    context "suspends a vm" do
      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(vm_href, gen_request(:suspend))
      end

      include_examples "single_action", :success => true, :message => "suspending", :href => :vm_href, :task => true
    end

    context "suspends multiple vms" do
      before do
        api_basic_authorize action_identifier(:vms, :suspend)

        run_post(vms_url, gen_request(:suspend, nil, vm1_url, vm2_url))
      end

      include_examples "multiple_actions", 2, :href_list => :vms_list, :task => true
    end
  end

  context "Vm delete action" do
    context "deletes an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :delete)

        run_post(invalid_vm_url, gen_request(:delete))
      end

      include_examples "resource_not_found"
    end

    context "deletes a vm via a resource POST without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:delete))
      end

      include_examples "request_forbidden"
    end

    context "deletes a vm via a resource DELETE without appropriate role" do
      before do
        api_basic_authorize

        run_delete(invalid_vm_url)
      end

      include_examples "request_forbidden"
    end

    context "deletes a vm via a resource POST" do
      before do
        api_basic_authorize action_identifier(:vms, :delete)

        run_post(vm_href, gen_request(:delete))
      end

      include_examples "single_action", :success => true, :message => "deleting", :href => :vm_href, :task => true
    end

    context "deletes a vm via a resource DELETE" do
      before do
        api_basic_authorize action_identifier(:vms, :delete)

        run_delete(vm_href)
      end

      include_examples "request_success_no_content"
    end

    context "deletes multiple vms" do
      before do
        api_basic_authorize action_identifier(:vms, :delete)

        run_post(vms_url, gen_request(:delete, nil, vm1_url, vm2_url))
      end

      include_examples "multiple_actions", 2, :task => true
    end
  end

  context "Vm set_owner action" do
    context "set_owner to an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(invalid_vm_url, gen_request(:set_owner, "owner" => "admin"))
      end

      include_examples "resource_not_found"
    end

    context "set_owner without appropriate action role" do
      before do
        api_basic_authorize

        run_post(vm_href, gen_request(:set_owner, "owner" => "admin"))
      end

      include_examples "request_forbidden"
    end

    context "set_owner with missing owner" do
      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(vm_href, gen_request(:set_owner))
      end

      include_examples "bad_request", "Must specify an owner"
    end

    context "set_owner with invalid owner" do
      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(vm_href, gen_request(:set_owner, "owner" => "bad_user"))
      end

      include_examples "single_action", :success => false, :message => /.*/, :href => :vm_href
    end

    context "set_owner to a vm" do
      def verify_successfully_updated_vm_owner
        expect(vm.reload.evm_owner).to eq(@user)
      end

      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(vm_href, gen_request(:set_owner, "owner" => @cfme[:user]))
      end

      include_examples "single_action",
                       :success        => true,
                       :message        => "setting owner",
                       :href           => :vm_href,
                       :custom_expects => :verify_successfully_updated_vm_owner
    end

    context "set_owner to multiple vms" do
      def verify_successfully_updated_owners_of_all_vms
        expect(vm1.reload.evm_owner).to eq(@user)
        expect(vm2.reload.evm_owner).to eq(@user)
      end

      before do
        api_basic_authorize action_identifier(:vms, :set_owner)

        run_post(vms_url, gen_request(:set_owner, {"owner" => @cfme[:user]}, vm1_url, vm2_url))
      end

      include_examples "multiple_actions", 2,
                       :href_list      => :vms_list,
                       :custom_expects => :verify_successfully_updated_owners_of_all_vms
    end
  end

  context "Vm custom_attributes" do
    let(:ca1) { FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1") }
    let(:ca2) { FactoryGirl.create(:custom_attribute, :name => "name2", :value => "value2") }
    let(:vm_ca_url)      { "#{vm_href}/custom_attributes" }
    let(:ca1_url)        { "#{vm_ca_url}/#{ca1.id}" }
    let(:ca2_url)        { "#{vm_ca_url}/#{ca2.id}" }
    let(:vm_ca_url_list) { [ca1_url, ca2_url] }

    context "getting custom_attributes from a vm with no custom_attributes" do
      before do
        api_basic_authorize

        run_get(vm_ca_url)
      end

      include_examples "empty_query_result", :custom_attributes
    end

    context "getting custom_attributes from a vm" do
      before do
        api_basic_authorize
        vm.custom_attributes = [ca1, ca2]

        run_get vm_ca_url
      end

      include_examples "query_result", :custom_attributes, 2, :includes_hrefs => ["resources", :vm_ca_url_list]
    end

    context "getting custom_attributes from a vm in expanded form" do
      before do
        api_basic_authorize
        vm.custom_attributes = [ca1, ca2]

        run_get "#{vm_ca_url}?expand=resources"
      end

      include_examples "query_result", :custom_attributes, 2, :includes_data => ["resources", "name" => %w(name1 name2)]
    end

    context "getting custom_attributes from a vm using expand" do
      before do
        api_basic_authorize
        vm.custom_attributes = [ca1, ca2]

        run_get "#{vm_href}?expand=custom_attributes"
      end

      include_examples "single_resource_query",
                       "guid"         => :vm_guid,
                       :includes_data => ["custom_attributes", "name" => %w(name1 name2)]
    end

    context "delete a custom_attribute without appropriate role" do
      before do
        api_basic_authorize
        vm.custom_attributes = [ca1]

        run_post(vm_ca_url, gen_request(:delete, nil, vm_href))
      end

      include_examples "request_forbidden"
    end

    context "delete a custom_attribute from a vm via the delete action" do
      def verify_updated_vm_has_no_custom_attributes
        expect(vm.reload.custom_attributes).to be_empty
      end

      before do
        api_basic_authorize action_identifier(:vms, :edit)
        vm.custom_attributes = [ca1]

        run_post(vm_ca_url, gen_request(:delete, nil, ca1_url))
      end

      include_examples "request_success", :custom_expects => :verify_updated_vm_has_no_custom_attributes
    end

    context "add custom attribute to a vm without a name" do
      before do
        api_basic_authorize action_identifier(:vms, :edit)

        run_post(vm_ca_url, gen_request(:add, "value" => "value1"))
      end

      include_examples "bad_request", "Must specify a name"
    end

    context "add custom attributes to a vm" do
      def verify_updated_vm_custom_attributes_match_request
        expect(vm.custom_attributes.size).to eq(2)
        expect(vm.custom_attributes.pluck(:value).sort).to eq(%w(value1 value2))
      end

      before do
        api_basic_authorize action_identifier(:vms, :edit)

        run_post(vm_ca_url, gen_request(:add, [{"name" => "name1", "value" => "value1"},
                                               {"name" => "name2", "value" => "value2"}]))
      end

      include_examples "request_success",
                       :includes_data  => ["results", "name" => %w(name1 name2)],
                       :custom_expects => :verify_updated_vm_custom_attributes_match_request
    end

    context "edit a custom attribute by name" do
      def verify_vm_custom_attribute_name_to_be_updated
        expect(vm.reload.custom_attributes.first.value).to eq("value one")
      end

      before do
        api_basic_authorize action_identifier(:vms, :edit)
        vm.custom_attributes = [ca1]

        run_post(vm_ca_url, gen_request(:edit, "name" => "name1", "value" => "value one"))
      end

      include_examples "request_success",
                       :includes_data  => ["results", "value" => ["value one"]],
                       :custom_expects => :verify_vm_custom_attribute_name_to_be_updated
    end

    context "edit a custom attribute by href" do
      def verify_vm_custom_attribute_name_to_be_updated
        expect(vm.reload.custom_attributes.first.value).to eq("new value1")
      end

      before do
        api_basic_authorize action_identifier(:vms, :edit)
        vm.custom_attributes = [ca1]

        run_post(vm_ca_url, gen_request(:edit, "href" => ca1_url, "value" => "new value1"))
      end

      include_examples "request_success",
                       :includes_data  => ["results", "value" => ["new value1"]],
                       :custom_expects => :verify_vm_custom_attribute_name_to_be_updated
    end

    context "edit multiple custom attributes" do
      def verify_vm_custom_attribute_names_to_be_updated
        expect(vm.reload.custom_attributes.pluck(:value).sort).to eq(["new value1", "new value2"])
      end

      before do
        api_basic_authorize action_identifier(:vms, :edit)
        vm.custom_attributes = [ca1, ca2]

        run_post(vm_ca_url, gen_request(:edit, [{"name" => "name1", "value" => "new value1"},
                                                {"name" => "name2", "value" => "new value2"}]))
      end

      include_examples "request_success",
                       :includes_data  => ["results", "value" => ["new value1", "new value2"]],
                       :custom_expects => :verify_vm_custom_attribute_names_to_be_updated
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

      include_examples "resource_not_found"
    end

    context "add_lifecycle_event without appropriate action role" do
      before do
        api_basic_authorize

        run_post(vm_href, gen_request(:add_lifecycle_event, :event => "event 1"))
      end

      include_examples "request_forbidden"
    end

    context "add_lifecycle_event to a vm" do
      def verify_vm_lifecycle_events_created
        expect(vm.lifecycle_events.size).to eq(1)
        expect(vm.lifecycle_events.first.event).to eq(events[0][:event])
      end

      before do
        api_basic_authorize action_identifier(:vms, :add_lifecycle_event)

        run_post(vm_href, gen_request(:add_lifecycle_event, events[0]))
      end

      include_examples "single_action",
                       :success        => true,
                       :message        => /adding lifecycle event/i,
                       :href           => :vm_href,
                       :custom_expects => :verify_vm_lifecycle_events_created
    end

    context "add_lifecycle_event to multiple vms" do
      def verify_events_were_added_to_the_vms
        expect(vm.lifecycle_events.size).to eq(events.size)
        expect(vm.lifecycle_events.collect(&:event)).to match_array(events.collect { |e| e[:event] })
      end

      before do
        api_basic_authorize action_identifier(:vms, :add_lifecycle_event)

        run_post(vms_url, gen_request(:add_lifecycle_event,
                                      events.collect { |e| {:href => vm_href}.merge(e) }))
      end

      include_examples "multiple_actions", 3, :custom_expects => :verify_events_were_added_to_the_vms
    end
  end

  context "Vm scan action" do
    context "scans an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :scan)

        run_post(invalid_vm_url, gen_request(:scan))
      end

      include_examples "resource_not_found"
    end

    context "scans an invalid Vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:scan))
      end

      include_examples "request_forbidden"
    end

    context "scan a Vm" do
      before do
        api_basic_authorize action_identifier(:vms, :scan)

        run_post(vm_href, gen_request(:scan))
      end

      include_examples "single_action", :success => true, :message => "scanning", :href => :vm_href, :task => true
    end

    context "scan multiple Vms" do
      before do
        api_basic_authorize action_identifier(:vms, :scan)

        run_post(vms_url, gen_request(:scan, nil, vm1_url, vm2_url))
      end

      include_examples "multiple_actions", 2, :href_list => :vms_list, :task => true
    end
  end

  context "Vm add_event action" do
    context "to an invalid vm" do
      before do
        api_basic_authorize action_identifier(:vms, :add_event)

        run_post(invalid_vm_url, gen_request(:add_event))
      end

      include_examples "resource_not_found"
    end

    context "to an invalid vm without appropriate role" do
      before do
        api_basic_authorize

        run_post(invalid_vm_url, gen_request(:add_event))
      end

      include_examples "request_forbidden"
    end

    context "to a single Vm" do
      before do
        api_basic_authorize collection_action_identifier(:vms, :add_event)

        run_post(vm_href, gen_request(:add_event, :event_type => "special", :event_message => "message"))
      end

      include_examples "single_action", :success => true, :message => /adding event/i, :href => :vm_href
    end

    context "to multiple Vms" do
      before do
        api_basic_authorize collection_action_identifier(:vms, :add_event)

        run_post(vms_url,
                 gen_request(:add_event,
                             [{"href" => vm1_url, "event_type" => "etype1", "event_message" => "emsg1"},
                              {"href" => vm2_url, "event_type" => "etype2", "event_message" => "emsg2"}]))
      end

      include_examples "multiple_actions",
                       2,
                       :href_list      => :vms_list,
                       :match_key_data => ["results", "message", [/adding event .*etype1/i, /adding event .*etype2/i]]
    end
  end
end
