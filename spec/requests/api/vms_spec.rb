#
# REST API Request Tests - /api/vms
#
describe ApiController do
  let(:zone)       { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:miq_server) { FactoryGirl.create(:miq_server, :guid => miq_server_guid, :zone => zone) }
  let(:ems)        { FactoryGirl.create(:ems_vmware, :zone => zone) }
  let(:host)       { FactoryGirl.create(:host) }

  let(:vm)                 { FactoryGirl.create(:vm_vmware,    :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm_openstack)       { FactoryGirl.create(:vm_openstack, :host => host, :ems_id => ems.id, :raw_power_state => "ACTIVE") }
  let(:vm_openstack1)      { FactoryGirl.create(:vm_openstack, :host => host, :ems_id => ems.id, :raw_power_state => "ACTIVE") }
  let(:vm_openstack2)      { FactoryGirl.create(:vm_openstack, :host => host, :ems_id => ems.id, :raw_power_state => "ACTIVE") }
  let(:vm_openstack_url)   { vms_url(vm_openstack.id) }
  let(:vm_openstack1_url)  { vms_url(vm_openstack1.id) }
  let(:vm_openstack2_url)  { vms_url(vm_openstack2.id) }
  let(:vms_openstack_list) { [vm_openstack1_url, vm_openstack2_url] }
  let(:vm1)                { FactoryGirl.create(:vm_vmware,    :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm2)                { FactoryGirl.create(:vm_vmware,    :host => host, :ems_id => ems.id, :raw_power_state => "poweredOn") }
  let(:vm1_url)            { vms_url(vm1.id) }
  let(:vm2_url)            { vms_url(vm2.id) }
  let(:vms_list)           { [vm1_url, vm2_url] }
  let(:vm_guid)            { vm.guid }
  let(:vm_url)             { vms_url(vm.id) }

  let(:invalid_vm_url) { vms_url(999_999) }

  def update_raw_power_state(state, *vms)
    vms.each { |vm| vm.update_attributes!(:raw_power_state => state) }
  end

  context "Vm accounts subcollection" do
    let(:acct1) { FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "John") }
    let(:acct2) { FactoryGirl.create(:account, :vm_or_template_id => vm.id, :name => "Jane") }
    let(:vm_accounts_url)      { "#{vms_url(vm.id)}/accounts" }
    let(:acct1_url)            { "#{vm_accounts_url}/#{acct1.id}" }
    let(:acct2_url)            { "#{vm_accounts_url}/#{acct2.id}" }
    let(:vm_accounts_url_list) { [acct1_url, acct2_url] }

    it "query VM accounts subcollection with no related accounts" do
      api_basic_authorize

      run_get vm_accounts_url

      expect_empty_query_result(:accounts)
    end

    it "query VM accounts subcollection with two related accounts" do
      api_basic_authorize
      # create resources
      acct1
      acct2

      run_get vm_accounts_url

      expect_query_result(:accounts, 2)
      expect_result_resources_to_include_hrefs("resources", :vm_accounts_url_list)
    end

    it "query VM accounts subcollection with a valid Account Id" do
      api_basic_authorize

      run_get acct1_url

      expect_single_resource_query("name" => "John")
    end

    it "query VM accounts subcollection with an invalid Account Id" do
      api_basic_authorize

      run_get "#{vm_accounts_url}/999999"

      expect_resource_not_found
    end

    it "query VM accounts subcollection with two related accounts using expand directive" do
      api_basic_authorize
      # create resources
      acct1
      acct2

      run_get vm_url, :expand => "accounts"

      expect_single_resource_query("guid" => :vm_guid)
      expect_result_resources_to_include_hrefs("accounts", :vm_accounts_url_list)
    end
  end

  context "Vm software subcollection" do
    let(:sw1) { FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Word")  }
    let(:sw2) { FactoryGirl.create(:guest_application, :vm_or_template_id => vm.id, :name => "Excel") }
    let(:vm_software_url)      { "#{vms_url(vm.id)}/software"    }
    let(:sw1_url)              { "#{vm_software_url}/#{sw1.id}" }
    let(:sw2_url)              { "#{vm_software_url}/#{sw2.id}" }
    let(:vm_software_url_list) { [sw1_url, sw2_url] }

    it "query VM software subcollection with no related software" do
      api_basic_authorize

      run_get vm_software_url

      expect_empty_query_result(:software)
    end

    it "query VM software subcollection with two related software" do
      api_basic_authorize
      # create resources
      sw1
      sw2

      run_get vm_software_url

      expect_query_result(:software, 2)
      expect_result_resources_to_include_hrefs("resources", :vm_software_url_list)
    end

    it "query VM software subcollection with a valid Software Id" do
      api_basic_authorize

      run_get sw1_url

      expect_single_resource_query("name" => "Word")
    end

    it "query VM software subcollection with an invalid Software Id" do
      api_basic_authorize

      run_get "#{vm_software_url}/999999"

      expect_resource_not_found
    end

    it "query VM software subcollection with two related software using expand directive" do
      api_basic_authorize
      # create resources
      sw1
      sw2

      run_get vms_url(vm.id), :expand => "software"

      expect_single_resource_query("guid" => :vm_guid)
      expect_result_resources_to_include_hrefs("software", :vm_software_url_list)
    end
  end

  context "Vm start action" do
    it "starts an invalid vm" do
      api_basic_authorize action_identifier(:vms, :start)

      run_post(invalid_vm_url, gen_request(:start))

      expect_resource_not_found
    end

    it "starts an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:start))

      expect_request_forbidden
    end

    it "starts a powered on vm" do
      api_basic_authorize action_identifier(:vms, :start)

      run_post(vm_url, gen_request(:start))

      expect_single_action_result(:success => false, :message => "is powered on", :href => :vm_url)
    end

    it "starts a vm" do
      api_basic_authorize action_identifier(:vms, :start)
      update_raw_power_state("poweredOff", vm)

      run_post(vm_url, gen_request(:start))

      expect_single_action_result(:success => true, :message => "starting", :href => :vm_url, :task => true)
    end

    it "starting a vm queues it properly" do
      api_basic_authorize action_identifier(:vms, :start)
      update_raw_power_state("poweredOff", vm)

      run_post(vm_url, gen_request(:start))

      expect_single_action_result(:success => true, :message => "starting", :href => :vm_url, :task => true)
      expect(MiqQueue.where(:class_name  => vm.class.name,
                            :instance_id => vm.id,
                            :method_name => "start",
                            :zone        => zone.name).count).to eq(1)
    end

    it "starts multiple vms" do
      api_basic_authorize action_identifier(:vms, :start)
      update_raw_power_state("poweredOff", vm1, vm2)

      run_post(vms_url, gen_request(:start, nil, vm1_url, vm2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", :vms_list)
    end
  end

  context "Vm stop action" do
    it "stops an invalid vm" do
      api_basic_authorize action_identifier(:vms, :stop)

      run_post(invalid_vm_url, gen_request(:stop))

      expect_resource_not_found
    end

    it "stops an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:stop))

      expect_request_forbidden
    end

    it "stops a powered off vm" do
      api_basic_authorize action_identifier(:vms, :stop)
      update_raw_power_state("poweredOff", vm)

      run_post(vm_url, gen_request(:stop))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => :vm_url)
    end

    it "stops a vm" do
      api_basic_authorize action_identifier(:vms, :stop)

      run_post(vm_url, gen_request(:stop))

      expect_single_action_result(:success => true, :message => "stopping", :href => :vm_url, :task => true)
    end

    it "stops multiple vms" do
      api_basic_authorize action_identifier(:vms, :stop)

      run_post(vms_url, gen_request(:stop, nil, vm1_url, vm2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", :vms_list)
    end
  end

  context "Vm suspend action" do
    it "suspends an invalid vm" do
      api_basic_authorize action_identifier(:vms, :suspend)

      run_post(invalid_vm_url, gen_request(:suspend))

      expect_resource_not_found
    end

    it "suspends an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:suspend))

      expect_request_forbidden
    end

    it "suspends a powered off vm" do
      api_basic_authorize action_identifier(:vms, :suspend)
      update_raw_power_state("poweredOff", vm)

      run_post(vm_url, gen_request(:suspend))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => :vm_url)
    end

    it "suspends a suspended vm" do
      api_basic_authorize action_identifier(:vms, :suspend)
      update_raw_power_state("suspended", vm)

      run_post(vm_url, gen_request(:suspend))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => :vm_url)
    end

    it "suspends a vm" do
      api_basic_authorize action_identifier(:vms, :suspend)

      run_post(vm_url, gen_request(:suspend))

      expect_single_action_result(:success => true, :message => "suspending", :href => :vm_url, :task => true)
    end

    it "suspends multiple vms" do
      api_basic_authorize action_identifier(:vms, :suspend)

      run_post(vms_url, gen_request(:suspend, nil, vm1_url, vm2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", :vms_list)
    end
  end

  context "Vm pause action" do
    it "pauses an invalid vm" do
      api_basic_authorize action_identifier(:vms, :pause)

      run_post(invalid_vm_url, gen_request(:pause))

      expect_resource_not_found
    end

    it "pauses an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:pause))

      expect_request_forbidden
    end

    it "pauses a powered off vm" do
      api_basic_authorize action_identifier(:vms, :pause)
      update_raw_power_state("off", vm)

      run_post(vm_url, gen_request(:pause))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => :vm_url)
    end

    it "pauses a pauseed vm" do
      api_basic_authorize action_identifier(:vms, :pause)
      update_raw_power_state("paused", vm)

      run_post(vm_url, gen_request(:pause))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => :vm_url)
    end

    it "pauses a vm" do
      api_basic_authorize action_identifier(:vms, :pause)

      run_post(vm_url, gen_request(:pause))

      expect_single_action_result(:success => true, :message => "pausing", :href => :vm_url, :task => true)
    end

    it "pauses multiple vms" do
      api_basic_authorize action_identifier(:vms, :pause)

      run_post(vms_url, gen_request(:pause, nil, vm1_url, vm2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", :vms_list)
    end
  end

  context "Vm shelve action" do
    it "shelves an invalid vm" do
      api_basic_authorize action_identifier(:vms, :shelve)

      run_post(invalid_vm_url, gen_request(:shelve))

      expect_resource_not_found
    end

    it "shelves an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:shelve))

      expect_request_forbidden
    end

    it "shelves a powered off vm" do
      api_basic_authorize action_identifier(:vms, :shelve)
      update_raw_power_state("SHUTOFF", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve))

      expect_single_action_result(:success => true, :message => 'shelving', :href => :vm_openstack_url)
    end

    it "shelves a suspended vm" do
      api_basic_authorize action_identifier(:vms, :shelve)
      update_raw_power_state("SUSPENDED", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve))

      expect_single_action_result(:success => true, :message => 'shelving', :href => :vm_openstack_url)
    end

    it "shelves a paused off vm" do
      api_basic_authorize action_identifier(:vms, :shelve)
      update_raw_power_state("PAUSED", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve))

      expect_single_action_result(:success => true, :message => 'shelving', :href => :vm_openstack_url)
    end

    it "shelves a shelveed vm" do
      api_basic_authorize action_identifier(:vms, :shelve)
      update_raw_power_state("SHELVED", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve))

      expect_single_action_result(:success => false,
                                  :message => "The VM can't be shelved, current state has to be powered on, off, suspended or paused",
                                  :href    => :vm_openstack_url)
    end

    it "shelves a vm" do
      api_basic_authorize action_identifier(:vms, :shelve)

      run_post(vm_openstack_url, gen_request(:shelve))

      expect_single_action_result(:success => true, :message => "shelving", :href => :vm_openstack_url, :task => true)
    end

    it "shelve for a VMWare vm is not supported" do
      api_basic_authorize action_identifier(:vms, :shelve)

      run_post(vm_url, gen_request(:shelve))

      expect_single_action_result(:success => false,
                                  :message => "Shelve Operation is not available for Vmware VM.",
                                  :href    => :vm_url,
                                  :task    => false)
    end

    it "shelves multiple vms" do
      api_basic_authorize action_identifier(:vms, :shelve)

      run_post(vms_url, gen_request(:shelve, nil, vm_openstack1_url, vm_openstack2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", :vms_openstack_list)
    end
  end

  context "Vm shelve offload action" do
    it "shelve_offloads an invalid vm" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)

      run_post(invalid_vm_url, gen_request(:shelve_offload))

      expect_resource_not_found
    end

    it "shelve_offloads an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:shelve_offload))

      expect_request_forbidden
    end

    it "shelve_offloads a active vm" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)

      run_post(vm_openstack_url, gen_request(:shelve_offload))

      expect_single_action_result(:success => false,
                                  :message => "The VM can't be shelved offload, current state has to be shelved",
                                  :href    => :vm_openstack_url)
    end

    it "shelve_offloads a powered off vm" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)
      update_raw_power_state("SHUTOFF", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve_offload))

      expect_single_action_result(:success => false,
                                  :message => "The VM can't be shelved offload, current state has to be shelved",
                                  :href    => :vm_openstack_url)
    end

    it "shelve_offloads a suspended vm" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)
      update_raw_power_state("SUSPENDED", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve_offload))

      expect_single_action_result(:success => false,
                                  :message => "The VM can't be shelved offload, current state has to be shelved",
                                  :href    => :vm_openstack_url)
    end

    it "shelve_offloads a paused off vm" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)
      update_raw_power_state("PAUSED", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve_offload))

      expect_single_action_result(:success => false,
                                  :message => "The VM can't be shelved offload, current state has to be shelved",
                                  :href    => :vm_openstack_url)
    end

    it "shelve_offloads a shelve_offloaded vm" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)
      update_raw_power_state("SHELVED_OFFLOADED", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve_offload))

      expect_single_action_result(:success => false,
                                  :message => "The VM can't be shelved offload, current state has to be shelved",
                                  :href    => :vm_openstack_url)
    end

    it "shelve_offloads a shelved vm" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)
      update_raw_power_state("SHELVED", vm_openstack)

      run_post(vm_openstack_url, gen_request(:shelve_offload))

      expect_single_action_result(:success => true,
                                  :message => "shelve-offloading",
                                  :href    => :vm_openstack_url)
    end

    it "shelve_offload for a VMWare vm is not supported" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)

      run_post(vm_url, gen_request(:shelve_offload))

      expect_single_action_result(:success => false,
                                  :message => "Shelve Offload Operation is not available for Vmware VM.",
                                  :href    => :vm_url,
                                  :task    => false)
    end

    it "shelve_offloads multiple vms" do
      api_basic_authorize action_identifier(:vms, :shelve_offload)

      update_raw_power_state("SHELVED", vm_openstack1)
      update_raw_power_state("SHELVED", vm_openstack2)

      run_post(vms_url, gen_request(:shelve_offload, nil, vm_openstack1_url, vm_openstack2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", :vms_openstack_list)
    end
  end

  context "Vm delete action" do
    it "deletes an invalid vm" do
      api_basic_authorize action_identifier(:vms, :delete)

      run_post(invalid_vm_url, gen_request(:delete))

      expect_resource_not_found
    end

    it "deletes a vm via a resource POST without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:delete))

      expect_request_forbidden
    end

    it "deletes a vm via a resource DELETE without appropriate role" do
      api_basic_authorize

      run_delete(invalid_vm_url)

      expect_request_forbidden
    end

    it "deletes a vm via a resource POST" do
      api_basic_authorize action_identifier(:vms, :delete)

      run_post(vm_url, gen_request(:delete))

      expect_single_action_result(:success => true, :message => "deleting", :href => :vm_url, :task => true)
    end

    it "deletes a vm via a resource DELETE" do
      api_basic_authorize action_identifier(:vms, :delete)

      run_delete(vm_url)

      expect_request_success_with_no_content
    end

    it "deletes multiple vms" do
      api_basic_authorize action_identifier(:vms, :delete)

      run_post(vms_url, gen_request(:delete, nil, vm1_url, vm2_url))

      expect_multiple_action_result(2, :task => true)
    end
  end

  context "Vm set_owner action" do
    it "set_owner to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :set_owner)

      run_post(invalid_vm_url, gen_request(:set_owner, "owner" => "admin"))

      expect_resource_not_found
    end

    it "set_owner without appropriate action role" do
      api_basic_authorize

      run_post(vm_url, gen_request(:set_owner, "owner" => "admin"))

      expect_request_forbidden
    end

    it "set_owner with missing owner" do
      api_basic_authorize action_identifier(:vms, :set_owner)

      run_post(vm_url, gen_request(:set_owner))

      expect_bad_request("Must specify an owner")
    end

    it "set_owner with invalid owner" do
      api_basic_authorize action_identifier(:vms, :set_owner)

      run_post(vm_url, gen_request(:set_owner, "owner" => "bad_user"))

      expect_single_action_result(:success => false, :message => /.*/, :href => :vm_url)
    end

    it "set_owner to a vm" do
      api_basic_authorize action_identifier(:vms, :set_owner)

      run_post(vm_url, gen_request(:set_owner, "owner" => api_config(:user)))

      expect_single_action_result(:success => true, :message => "setting owner", :href => :vm_url)
      expect(vm.reload.evm_owner).to eq(@user)
    end

    it "set_owner to multiple vms" do
      api_basic_authorize action_identifier(:vms, :set_owner)

      run_post(vms_url, gen_request(:set_owner, {"owner" => api_config(:user)}, vm1_url, vm2_url))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :vms_list)
      expect(vm1.reload.evm_owner).to eq(@user)
      expect(vm2.reload.evm_owner).to eq(@user)
    end
  end

  context "Vm custom_attributes" do
    let(:ca1) { FactoryGirl.create(:custom_attribute, :name => "name1", :value => "value1") }
    let(:ca2) { FactoryGirl.create(:custom_attribute, :name => "name2", :value => "value2") }
    let(:vm_ca_url)      { "#{vm_url}/custom_attributes" }
    let(:ca1_url)        { "#{vm_ca_url}/#{ca1.id}" }
    let(:ca2_url)        { "#{vm_ca_url}/#{ca2.id}" }
    let(:vm_ca_url_list) { [ca1_url, ca2_url] }

    it "getting custom_attributes from a vm with no custom_attributes" do
      api_basic_authorize

      run_get(vm_ca_url)

      expect_empty_query_result(:custom_attributes)
    end

    it "getting custom_attributes from a vm" do
      api_basic_authorize
      vm.custom_attributes = [ca1, ca2]

      run_get vm_ca_url

      expect_query_result(:custom_attributes, 2)
      expect_result_resources_to_include_hrefs("resources", :vm_ca_url_list)
    end

    it "getting custom_attributes from a vm in expanded form" do
      api_basic_authorize
      vm.custom_attributes = [ca1, ca2]

      run_get vm_ca_url, :expand => "resources"

      expect_query_result(:custom_attributes, 2)
      expect_result_resources_to_include_data("resources", "name" => %w(name1 name2))
    end

    it "getting custom_attributes from a vm using expand" do
      api_basic_authorize
      vm.custom_attributes = [ca1, ca2]

      run_get vm_url, :expand => "custom_attributes"

      expect_single_resource_query("guid" => :vm_guid)
      expect_result_resources_to_include_data("custom_attributes", "name" => %w(name1 name2))
    end

    it "delete a custom_attribute without appropriate role" do
      api_basic_authorize
      vm.custom_attributes = [ca1]

      run_post(vm_ca_url, gen_request(:delete, nil, vm_url))

      expect_request_forbidden
    end

    it "delete a custom_attribute from a vm via the delete action" do
      api_basic_authorize action_identifier(:vms, :edit)
      vm.custom_attributes = [ca1]

      run_post(vm_ca_url, gen_request(:delete, nil, ca1_url))

      expect_request_success
      expect(vm.reload.custom_attributes).to be_empty
    end

    it "add custom attribute to a vm without a name" do
      api_basic_authorize action_identifier(:vms, :edit)

      run_post(vm_ca_url, gen_request(:add, "value" => "value1"))

      expect_bad_request("Must specify a name")
    end

    it "add custom attributes to a vm" do
      api_basic_authorize action_identifier(:vms, :edit)

      run_post(vm_ca_url, gen_request(:add, [{"name" => "name1", "value" => "value1"},
                                             {"name" => "name2", "value" => "value2"}]))

      expect_request_success
      expect_result_resources_to_include_data("results", "name" => %w(name1 name2))
      expect(vm.custom_attributes.size).to eq(2)
      expect(vm.custom_attributes.pluck(:value).sort).to eq(%w(value1 value2))
    end

    it "edit a custom attribute by name" do
      api_basic_authorize action_identifier(:vms, :edit)
      vm.custom_attributes = [ca1]

      run_post(vm_ca_url, gen_request(:edit, "name" => "name1", "value" => "value one"))

      expect_request_success
      expect_result_resources_to_include_data("results", "value" => ["value one"])
      expect(vm.reload.custom_attributes.first.value).to eq("value one")
    end

    it "edit a custom attribute by href" do
      api_basic_authorize action_identifier(:vms, :edit)
      vm.custom_attributes = [ca1]

      run_post(vm_ca_url, gen_request(:edit, "href" => ca1_url, "value" => "new value1"))

      expect_request_success
      expect_result_resources_to_include_data("results", "value" => ["new value1"])
      expect(vm.reload.custom_attributes.first.value).to eq("new value1")
    end

    it "edit multiple custom attributes" do
      api_basic_authorize action_identifier(:vms, :edit)
      vm.custom_attributes = [ca1, ca2]

      run_post(vm_ca_url, gen_request(:edit, [{"name" => "name1", "value" => "new value1"},
                                              {"name" => "name2", "value" => "new value2"}]))

      expect_request_success
      expect_result_resources_to_include_data("results", "value" => ["new value1", "new value2"])
      expect(vm.reload.custom_attributes.pluck(:value).sort).to eq(["new value1", "new value2"])
    end
  end

  context "Vm add_lifecycle_event action" do
    let(:events) do
      1.upto(3).collect do |n|
        {:event => "event#{n}", :status => "status#{n}", :message => "message#{n}", :created_by => "system"}
      end
    end

    it "add_lifecycle_event to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :add_lifecycle_event)

      run_post(invalid_vm_url, gen_request(:add_lifecycle_event, :event => "event 1"))

      expect_resource_not_found
    end

    it "add_lifecycle_event without appropriate action role" do
      api_basic_authorize

      run_post(vm_url, gen_request(:add_lifecycle_event, :event => "event 1"))

      expect_request_forbidden
    end

    it "add_lifecycle_event to a vm" do
      api_basic_authorize action_identifier(:vms, :add_lifecycle_event)

      run_post(vm_url, gen_request(:add_lifecycle_event, events[0]))

      expect_single_action_result(:success => true, :message => /adding lifecycle event/i, :href => :vm_url)
      expect(vm.lifecycle_events.size).to eq(1)
      expect(vm.lifecycle_events.first.event).to eq(events[0][:event])
    end

    it "add_lifecycle_event to multiple vms" do
      api_basic_authorize action_identifier(:vms, :add_lifecycle_event)

      run_post(vms_url, gen_request(:add_lifecycle_event,
                                    events.collect { |e| {:href => vm_url}.merge(e) }))

      expect_multiple_action_result(3)
      expect(vm.lifecycle_events.size).to eq(events.size)
      expect(vm.lifecycle_events.collect(&:event)).to match_array(events.collect { |e| e[:event] })
    end
  end

  context "Vm scan action" do
    it "scans an invalid vm" do
      api_basic_authorize action_identifier(:vms, :scan)

      run_post(invalid_vm_url, gen_request(:scan))

      expect_resource_not_found
    end

    it "scans an invalid Vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:scan))

      expect_request_forbidden
    end

    it "scan a Vm" do
      api_basic_authorize action_identifier(:vms, :scan)

      run_post(vm_url, gen_request(:scan))

      expect_single_action_result(:success => true, :message => "scanning", :href => :vm_url, :task => true)
    end

    it "scan multiple Vms" do
      api_basic_authorize action_identifier(:vms, :scan)

      run_post(vms_url, gen_request(:scan, nil, vm1_url, vm2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", :vms_list)
    end
  end

  context "Vm add_event action" do
    it "to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :add_event)

      run_post(invalid_vm_url, gen_request(:add_event))

      expect_resource_not_found
    end

    it "to an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:add_event))

      expect_request_forbidden
    end

    it "to a single Vm" do
      api_basic_authorize collection_action_identifier(:vms, :add_event)

      run_post(vm_url, gen_request(:add_event, :event_type => "special", :event_message => "message"))

      expect_single_action_result(:success => true, :message => /adding event/i, :href => :vm_url)
    end

    it "to multiple Vms" do
      api_basic_authorize collection_action_identifier(:vms, :add_event)

      run_post(vms_url,
               gen_request(:add_event,
                           [{"href" => vm1_url, "event_type" => "etype1", "event_message" => "emsg1"},
                            {"href" => vm2_url, "event_type" => "etype2", "event_message" => "emsg2"}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :vms_list)
      expect_result_resources_to_match_key_data("results", "message",
                                                [/adding event .*etype1/i, /adding event .*etype2/i])
    end
  end

  context "Vm retire action" do
    it "to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :retire)

      run_post(invalid_vm_url, gen_request(:retire))

      expect_resource_not_found
    end

    it "to an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:retire))

      expect_request_forbidden
    end

    it "to a single Vm" do
      api_basic_authorize action_identifier(:vms, :retire)

      run_post(vm_url, gen_request(:retire))

      expect_single_action_result(:success => true, :message => /#{vm.id}.* retiring/i, :href => :vm_url)
    end

    it "to multiple Vms" do
      api_basic_authorize collection_action_identifier(:vms, :retire)

      run_post(vms_url, gen_request(:retire, [{"href" => vm1_url}, {"href" => vm2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :vms_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/#{vm1.id}.* retiring/i, /#{vm2.id}.* retiring/i]
      )
    end

    it "in the future" do
      api_basic_authorize action_identifier(:vms, :retire)
      date = 2.weeks.from_now.to_date
      run_post(vm_url, gen_request(:retire, :date => date.strftime("%m/%d/%Y")))

      expect_single_action_result(:success => true, :message => /#{vm.id}.* retiring/i, :href => :vm_url)
    end
  end

  context "Vm reset action" do
    it "to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :reset)

      run_post(invalid_vm_url, gen_request(:reset))

      expect_resource_not_found
    end

    it "to an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:reset))

      expect_request_forbidden
    end

    it "to a single Vm" do
      api_basic_authorize action_identifier(:vms, :reset)

      run_post(vm_url, gen_request(:reset))

      expect_single_action_result(:success => true, :message => /#{vm.id}.* resetting/i, :href => :vm_url)
    end

    it "to multiple Vms" do
      api_basic_authorize collection_action_identifier(:vms, :reset)

      run_post(vms_url, gen_request(:reset, [{"href" => vm1_url}, {"href" => vm2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :vms_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/#{vm1.id}.* resetting/i, /#{vm2.id}.* resetting/i]
      )
    end
  end

  context "Vm shutdown guest action" do
    it "to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :shutdown_guest)

      run_post(invalid_vm_url, gen_request(:shutdown_guest))

      expect_resource_not_found
    end

    it "to an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:shutdown_guest))

      expect_request_forbidden
    end

    it "to a single Vm" do
      api_basic_authorize action_identifier(:vms, :shutdown_guest)

      run_post(vm_url, gen_request(:shutdown_guest))

      expect_single_action_result(:success => true, :message => /#{vm.id}.* shutting down/i, :href => :vm_url)
    end

    it "to multiple Vms" do
      api_basic_authorize collection_action_identifier(:vms, :shutdown_guest)

      run_post(vms_url, gen_request(:shutdown_guest, [{"href" => vm1_url}, {"href" => vm2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :vms_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/#{vm1.id}.* shutting down/i, /#{vm2.id}.* shutting down/i]
      )
    end
  end

  context "Vm refresh action" do
    it "to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :refresh)

      run_post(invalid_vm_url, gen_request(:refresh))

      expect_resource_not_found
    end

    it "to an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:refresh))

      expect_request_forbidden
    end

    it "to a single Vm" do
      api_basic_authorize action_identifier(:vms, :refresh)

      run_post(vm_url, gen_request(:refresh))

      expect_single_action_result(:success => true, :message => /#{vm.id}.* refreshing/i, :href => :vm_url)
    end

    it "to multiple Vms" do
      api_basic_authorize collection_action_identifier(:vms, :refresh)

      run_post(vms_url, gen_request(:refresh, [{"href" => vm1_url}, {"href" => vm2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :vms_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/#{vm1.id}.* refreshing/i, /#{vm2.id}.* refreshing/i]
      )
    end
  end

  context "Vm reboot guest action" do
    it "to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :reboot_guest)

      run_post(invalid_vm_url, gen_request(:reboot_guest))

      expect_resource_not_found
    end

    it "to an invalid vm without appropriate role" do
      api_basic_authorize

      run_post(invalid_vm_url, gen_request(:reboot_guest))

      expect_request_forbidden
    end

    it "to a single Vm" do
      api_basic_authorize action_identifier(:vms, :reboot_guest)

      run_post(vm_url, gen_request(:reboot_guest))

      expect_single_action_result(:success => true, :message => /#{vm.id}.* rebooting/i, :href => :vm_url)
    end

    it "to multiple Vms" do
      api_basic_authorize collection_action_identifier(:vms, :reboot_guest)

      run_post(vms_url, gen_request(:reboot_guest, [{"href" => vm1_url}, {"href" => vm2_url}]))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", :vms_list)
      expect_result_resources_to_match_key_data(
        "results",
        "message",
        [/#{vm1.id}.* rebooting/i, /#{vm2.id}.* rebooting/i]
      )
    end
  end
end
