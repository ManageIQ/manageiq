describe MiqProvisionVirtWorkflow do
  let(:workflow) { FactoryGirl.create(:miq_provision_virt_workflow) }

  context "#new" do
    let(:sdn)  { 'SysprepDomainName' }
    let(:host) { double('Host', :id => 1, :name => 'my_host') }
    let(:user) { FactoryGirl.create(:user_with_email) }

    before do
      allow(workflow).to receive_messages(:validate => true)
      allow(workflow).to receive_messages(:get_dialogs => {})
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => 123, :sysprep_enabled => 'fields',
                                     :sysprep_domain_name => sdn)
    end

    it "calls password_helper once when a block is not passed in" do
      expect_any_instance_of(MiqProvisionVirtWorkflow).to receive(:password_helper).with({:allowed_hosts    => [host],
                                                                                          :skip_dialog_load => true}, false).once
      MiqProvisionVirtWorkflow.new({:allowed_hosts => [host]}, user, :skip_dialog_load => true)
    end

    it "sets initial_pass equal to true when values are empty and initial_pass => true is passed in as an option" do
      expect_any_instance_of(MiqProvisionVirtWorkflow).to receive(:get_value).once

      init_options = {:use_pre_dialog => false, :skip_dialog_load => true, :request_type => :clone_to_vm, :initial_pass => true}
      p = MiqProvisionVirtWorkflow.new({}, user, init_options)

      expect(p.instance_variable_get(:@values)[:initial_pass]).to be_truthy
      expect(p.instance_variable_get(:@values)[:request_type]).to eq :clone_to_vm
    end
  end

  context "#continue_request" do
    let(:sdn) { 'SysprepDomainName' }

    before do
      allow(workflow).to receive_messages(:validate => true)
      allow(workflow).to receive_messages(:get_dialogs => {})
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => 123, :sysprep_enabled => 'fields',
                                     :sysprep_domain_name => sdn)
    end

    context "exit_pre_dialog" do
      it "doesn't exit when not running" do
        expect(workflow).not_to receive(:exit_pre_dialog)

        expect(workflow.continue_request({})).to be_truthy
      end

      it "exits when running" do
        workflow.instance_variable_set(:@running_pre_dialog, true)
        new_values = workflow.instance_variable_get(:@values)

        expect(workflow).to receive(:exit_pre_dialog).once.and_call_original

        expect(workflow.continue_request({})).to                        be_truthy
        expect(workflow.instance_variable_get(:@last_vm_id)).to         eq(123)
        expect(workflow.instance_variable_get(:@running_pre_dialog)).to be_falsey
        expect(workflow.instance_variable_get(:@tags)).to               be_nil
        expect(new_values[:forced_sysprep_enabled]).to                  eq('fields')
        expect(new_values[:forced_sysprep_domain_name]).to              eq([sdn])
        expect(new_values[:sysprep_domain_name]).to                     eq([sdn, sdn])
        expect(new_values[:vm_tags]).to                                 be_kind_of(Array)
      end
    end
  end

  context 'network selection' do
    before do
      @ems      = FactoryGirl.create(:ems_vmware)
      @host1    = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
      @host2    = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
      @src_vm   = FactoryGirl.create(:vm_vmware, :host => @host1, :ems_id => @ems.id)
      @other_vm = FactoryGirl.create(:vm_vmware, :host => @host2, :ems_id => @ems.id)
      allow(Rbac).to receive(:search) do |hash|
        [Array.wrap(hash[:targets])]
      end
      allow_any_instance_of(VmOrTemplate).to receive(:archived?).with(no_args).and_return(false)
      allow_any_instance_of(VmOrTemplate).to receive(:orphaned?).with(no_args).and_return(false)
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id)
      workflow.instance_variable_set(:@target_resource, nil)
    end

    context 'vlans' do
      before do
        s11 = FactoryGirl.create(:switch, :name => "A")
        s12 = FactoryGirl.create(:switch, :name => "B")
        s13 = FactoryGirl.create(:switch, :name => "C")
        s14 = FactoryGirl.create(:switch, :name => "D")
        @src_vm.host.switches   = [s11, s12, s13]
        @other_vm.host.switches = [s14]
        @lan11 = FactoryGirl.create(:lan, :name => "lan_A", :switch_id => s11.id)
        @lan12 = FactoryGirl.create(:lan, :name => "lan_B", :switch_id => s12.id)
        @lan13 = FactoryGirl.create(:lan, :name => "lan_C", :switch_id => s13.id)
        @lan14 = FactoryGirl.create(:lan, :name => "lan_D", :switch_id => s14.id)
      end

      it '#allowed_vlans' do
        allowed_hosts = [
          workflow.host_to_hash_struct(@host1),
          workflow.host_to_hash_struct(@host2)
        ]
        allow(workflow).to receive(:allowed_hosts).with(no_args).and_return(allowed_hosts)
        vlans = workflow.allowed_vlans(:vlans => true, :dvs => false)
        lan_keys = [@lan11.name, @lan13.name, @lan12.name, @lan14.name]
        expect(vlans.keys).to match_array(lan_keys)
        expect(vlans.values).to match_array(lan_keys)
      end

      it '#load_hosts_vlans' do
        hosts = [@host1, @host2]
        expect { workflow.load_hosts_vlans(hosts, {}) }.not_to exceed_query_limit(1)
      end
    end
  end

  context '#allowed_hosts_obj' do
    before do
      @ems    = FactoryGirl.create(:ems_vmware)
      @host1  = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
      @host2  = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
      @src_vm = FactoryGirl.create(:vm_vmware, :ems_id => @ems.id)
      allow(workflow).to receive(:find_all_ems_of_type).and_return([@host1, @host2])
      allow(Rbac).to receive(:search) do |hash|
        [Array.wrap(hash[:targets])]
      end
      workflow.instance_variable_set(:@target_resource, nil)

      s1 = FactoryGirl.create(:switch, :name => "A")
      s2 = FactoryGirl.create(:switch, :name => "B")
      @host1.switches = [s1]
      @host2.switches = [s2]
      @lan1 = FactoryGirl.create(:lan, :name => "lan_A", :switch_id => s1.id)
      @lan2 = FactoryGirl.create(:lan, :name => "lan_B", :switch_id => s2.id)
    end

    it 'finds all hosts with no selected network' do
      workflow.instance_variable_set(:@values, :src_vm_id => @src_vm.id)
      expect(workflow.allowed_hosts_obj).to match_array([@host1, @host2])
    end

    it 'finds only the hosts that can access the selected network' do
      workflow.instance_variable_set(:@values, :src_vm_id => @src_vm.id, :vlan => [@lan1.name, @lan1.name])
      expect(workflow.allowed_hosts_obj).to match_array([@host1])
    end
  end

  context "#update_requester_from_parameters" do
    let(:user_new) { FactoryGirl.create(:user_with_email) }
    let(:data_new_user) { {:user_name => user_new.name} }
    let(:current_user) { FactoryGirl.create(:user_with_email) }

    it "finds and sets a new user if one is passed in" do
      expect(User).to receive(:lookup_by_identity).and_return(user_new).once
      expect(MiqProvisionVirtWorkflow.update_requester_from_parameters(data_new_user, current_user)).to eq user_new
    end

    it "returns the original user if a new one is not passed in" do
      data_no_user = {}
      expect(User).to_not receive(:lookup_by_identity)
      expect(MiqProvisionVirtWorkflow.update_requester_from_parameters(data_no_user, current_user)).to eq current_user
    end

    it "raises an error if the lookup fails" do
      expect(User).to receive(:lookup_by_identity).and_return(nil).once
      expect { MiqProvisionVirtWorkflow.update_requester_from_parameters(data_new_user, current_user) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "#validate email formatting" do
    context "with specific format regex" do
      let(:regex) { {:required_regex => %r{\A[\w!#$\%&'*+/=?`\{|\}~^-]+(?:\.[\w!#$\%&'*+/=?`\{|\}~^-]+)*@(?:[A-Z0-9-]+\.)+[A-Z]{2,6}\Z}i} }
      let(:value_email) { 'n@test.com' }
      let(:value_no_email) { 'n' }

      it "matches a valid email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, value_email)).to be_nil
      end

      it "returns a formatting error message with a bad email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, value_no_email)).to eq "'/' must be correctly formatted"
      end

      it "returns an email required error with a blank email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, '')).to eq "'/' is required"
      end
    end

    context "with a match anything regex" do
      let(:regex) { {:required_regex => '.'} }
      let(:value_email) { 'n@test.com' }
      let(:value_no_email) { 'n' }

      it "matches a valid email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, value_email)).to be_nil
      end

      it "matches a bad email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, value_no_email)).to be_nil
      end

      it "returns an email required error with a blank email address" do
        expect(workflow.validate_regex(nil, {}, {}, regex, '')).to eq "'/' is required"
      end
    end
  end

  context "#validate_memory_reservation" do
    let(:values) { {:vm_memory => %w(1024 1024)} }

    it "no size" do
      expect(workflow.validate_memory_reservation(nil, values, {}, {}, nil)).to be_nil
    end

    it "valid size" do
      expect(workflow.validate_memory_reservation(nil, values.merge(:memory_reserve => 1024), {}, {}, nil)).to be_nil
    end

    it "invalid size" do
      error = "Memory Reservation is larger than VM Memory"

      expect(workflow).to receive(:required_description).and_return("Memory")
      expect(workflow.validate_memory_reservation(nil, values.merge(:memory_reserve => 2048), {}, {}, nil)).to eq(error)
    end
  end

  context "#allowed_template_condition" do
    it "without a provider model defined" do
      expect(workflow.allowed_template_condition).to eq(["vms.template = ? AND vms.ems_id IS NOT NULL", true])
    end

    it "with a provider model defined" do
      ems = FactoryGirl.create(:ems_vmware)
      expect(workflow.class).to receive(:provider_model).once.and_return(ems.class)

      expect(workflow.allowed_template_condition).to eq(["vms.template = ? AND vms.ems_id in (?)", true, [ems.id]])
    end
  end

  context "#ws_find_template_or_vm" do
    let(:server) { double("MiqServer", :logon_status => :ready, :server_timezone => 'East') }
    let(:sdn) { 'SysprepDomainName' }

    before do
      allow(MiqServer).to receive(:my_server).with(no_args).and_return(server)
      allow(workflow).to receive_messages(:validate => true)
      allow(workflow).to receive_messages(:get_dialogs => {})
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => 123, :sysprep_enabled => 'fields',
                                     :sysprep_domain_name => sdn)
    end

    it "does a lookup when src_name is blank" do
      expect(workflow.ws_find_template_or_vm("", "", "asdf-adsf", "asdfadfasdf")).to be_nil
    end

    it "does a lookup when src_name is not blank" do
      expect(workflow.ws_find_template_or_vm("", "VMWARE", "asdf-adsf", "asdfadfasdf")).to be_nil
    end

    it "returns a hash struct if a vm or template is found" do
      ems    = FactoryGirl.create(:ems_vmware)
      host1  = FactoryGirl.create(:host_vmware, :ems_id => ems.id)
      src_vm = FactoryGirl.create(:vm_vmware, :host => host1, :ems_id => ems.id)
      allow(workflow).to receive(:source_vm_rbac_filter).and_return([src_vm])
      expect(workflow.ws_find_template_or_vm("", "VMWARE", "asdf-adsf", "asdfadfasdf")).to be_a(OpenStruct)
    end
  end

  describe "#update_field_visibility" do
    let(:workflow) do
      described_class.new(
        {
          :addr_mode                => "addr_mode",
          :linked_clone             => "linked_clone",
          :number_of_vms            => "123",
          :placement_auto           => true,
          :provision_type           => "provision_type",
          :retirement               => "321",
          :service_template_request => "service_template_request",
          :sysprep_auto_logon       => "sysprep_auto_logon",
          :sysprep_custom_spec      => "sysprep_custom_spec",
          :sysprep_enabled          => "sysprep_enabled"
        },
        requester,
        :skip_dialog_load => true
      )
    end

    let(:requester) { double("User") }

    let(:dialog_field_visibility_service) { double("DialogFieldVisibilityService") }

    let(:options_hash) do
      {
        :addr_mode                       => "addr_mode",
        :auto_placement_enabled          => true,
        :customize_fields_list           => [],
        :linked_clone                    => "linked_clone",
        :number_of_vms                   => 123,
        :platform                        => nil,
        :provision_type                  => "provision_type",
        :request_type                    => "template",
        :retirement                      => 321,
        :service_template_request        => "service_template_request",
        :snapshot_count                  => 0,
        :supports_customization_template => false,
        :supports_iso                    => false,
        :supports_pxe                    => false,
        :sysprep_auto_logon              => "sysprep_auto_logon",
        :sysprep_custom_spec             => "sysprep_custom_spec",
        :sysprep_enabled                 => "sysprep_enabled"
      }
    end
    let(:dialogs) do
      {
        :dialogs => {
          :dialog_name => {
            :fields => {:field_name => {}}
          }
        }
      }
    end

    before do
      allow(requester).to receive(:kind_of?).with(User).and_return(true)
      allow(DialogFieldVisibilityService).to receive(:new).and_return(dialog_field_visibility_service)
      allow(dialog_field_visibility_service).to receive(:determine_visibility).with(options_hash).and_return(
        "visibility_hash"
      )
      allow(dialog_field_visibility_service).to receive(:set_visibility_for_field).with(
        "visibility_hash", :field_name, {}
      )
      workflow.instance_variable_set(:@dialogs, dialogs)
    end

    it "delegates to the dialog_field_visibility_service with the correct options" do
      expect(dialog_field_visibility_service).to receive(:determine_visibility).with(options_hash)
      workflow.update_field_visibility
    end

    it "sets the visibility for all fields" do
      expect(dialog_field_visibility_service).to receive(:set_visibility_for_field).with(
        "visibility_hash", :field_name, {}
      )
      workflow.update_field_visibility
    end
  end

  context '#make_request (update)' do
    let(:template) do
      FactoryGirl.create(
        :template_vmware,
        :ext_management_system => FactoryGirl.create(:ems_vmware_with_authentication)
      )
    end
    let(:values)  { {:src_vm_id => [template.id, template.name]} }
    let(:request) { workflow.make_request(nil, :src_vm_id => [999, 'old_template']) }
    before { workflow.make_request(request, values) }

    it 'updates options' do
      expect(request.options).to include(values)
    end

    it 'updates soruce_id' do
      expect(request.source_id).to eq(template.id)
    end
  end

  context "#allowed_templates" do
    let(:external_region_id) do
      remote_region_number = ApplicationRecord.my_region_number + 1
      ApplicationRecord.region_to_range(remote_region_number).first
    end

    let(:remote_vmware) { FactoryGirl.create(:ems_vmware_with_authentication, :id => external_region_id) }
    let(:local_vmware)  { FactoryGirl.create(:ems_vmware_with_authentication) }

    it "only returns records from its region" do
      EvmSpecHelper.local_miq_server # Because there is no default timezone in settings
      FactoryGirl.create(:template_vmware, :ext_management_system => remote_vmware, :id => external_region_id)
      FactoryGirl.create(:template_vmware, :ext_management_system => local_vmware)

      expect(MiqTemplate.count).to eq(2)
      expect(workflow.allowed_templates.count).to eq(1)
    end
  end
end
