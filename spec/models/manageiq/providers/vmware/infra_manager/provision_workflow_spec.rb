silence_warnings { ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow.const_set("DIALOGS_VIA_AUTOMATE", false) }

describe ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin)    { FactoryGirl.create(:user_with_group) }
  let(:template) { FactoryGirl.create(:template_vmware) }

  before do
    EvmSpecHelper.local_miq_server
  end

  describe "#new" do
    it "pass platform attributes to automate" do
      stub_dialog(:get_dialogs)
      assert_automate_dialog_lookup(admin, "infra", "vmware", "get_pre_dialog_name", nil)

      described_class.new({}, admin.userid)
    end

    it "sets up workflow" do
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)
      workflow = described_class.new(values = {}, admin.userid)

      expect(workflow.requester).to eq(admin)
      expect(values).to eq({})
    end
  end

  describe "#make_request" do
    let(:alt_user) { FactoryGirl.create(:user_with_group) }
    it "creates and update a request" do
      stub_dialog(:get_pre_dialogs)
      stub_dialog(:get_dialogs)

      # if running_pre_dialog is set, it will run 'continue_request'
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_created",
        :target_class => "Vm",
        :userid       => admin.userid,
        :message      => "VM Provisioning requested by <#{admin.userid}> for Vm:#{template.id}"
      )

      # creates a request
      stub_get_next_vm_name

      # the dialogs populate this
      values.merge!(:src_vm_id => template.id, :vm_tags => [])

      request = workflow.make_request(nil, values)

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionRequest)
      expect(request.request_type).to eq("template")
      expect(request.description).to eq("Provision from [#{template.name}] to [New VM]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      stub_get_next_vm_name

      workflow = described_class.new(values, alt_user)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Provisioning request updated by <#{alt_user.userid}> for Vm:#{template.id}"
      )
      workflow.make_request(request, values)
    end
  end

  context 'provisioning a VM' do
    let(:workflow) { described_class.new({}, admin.userid) }
    before do
      @ems    = FactoryGirl.create(:ems_vmware)
      @host1  = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
      @host2  = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
      @src_vm = FactoryGirl.create(:vm_vmware, :host => @host1, :ems_id => @ems.id)
      stub_dialog(:get_dialogs)
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id)
      workflow.instance_variable_set(:@target_resource, nil)
    end

    context '#allowed_storage_profiles' do
      let(:profile) { FactoryGirl.create(:storage_profile, :name => 'Gold') }
      it 'when storage_profile selection is set, will not touch storage_profile selection value' do
        selected = []
        workflow.instance_variable_set(:@values, :src_vm_id => template.id, :placement_storage_profile => selected)
        workflow.allowed_storage_profiles
        values = workflow.instance_variable_get(:@values)
        expect(values[:placement_storage_profile]).to eq(selected)
      end

      context 'when storage_profile selection is not set' do
        it 'set storage_profile selection to [nil, nil] if template has no storage_profile' do
          template = FactoryGirl.create(:vm_vmware, :host => @host1, :ems_id => @ems.id)
          workflow.instance_variable_set(:@values, :src_vm_id => template.id, :placement_storage_profile => nil)
          workflow.allowed_storage_profiles
          values = workflow.instance_variable_get(:@values)
          expect(values[:placement_storage_profile]).to eq([nil, nil])
        end

        it 'set storage_profile selection to that of template if template has one' do
          template = FactoryGirl.create(:vm_vmware, :host => @host1, :ems_id => @ems.id, :storage_profile => profile)
          workflow.instance_variable_set(:@values, :src_vm_id => template.id, :placement_storage_profile => nil)
          workflow.allowed_storage_profiles
          values = workflow.instance_variable_get(:@values)
          expect(values[:placement_storage_profile]).to eq([profile.id, profile.name])
        end
      end

      context 'storage_profile filter' do
        let(:ems) { FactoryGirl.create(:ems_vmware, :storage_profiles => [profile]) }
        let(:template) { FactoryGirl.create(:vm_vmware, :ems_id => ems.id) }
        it 'list storage_profiles associated with ems' do
          workflow.instance_variable_set(:@values, :src_vm_id => template.id, :src_ems_id => ems.id)
          workflow.allowed_storage_profiles
          filters = workflow.instance_variable_get(:@filters)
          expect(filters[:StorageProfile]).to eq(profile.id => profile.name)
        end
      end
    end

    context '#set_on_vm_id_changed' do
      before(:each) do
        workflow.instance_variable_set(:@filters, :Host => {21 => "ESX 6.0"}, :StorageProfile => {1 => "Tag 1"})
        workflow.instance_variable_set(:@values, :src_vm_id => @src_vm.id, :placement_storage_profile => [])
        allow(workflow).to receive(:set_or_default_hardware_field_values).with(@src_vm)
      end
      it 'clears StorageProfile filter' do
        workflow.set_on_vm_id_changed
        filters = workflow.instance_variable_get(:@filters)
        expect(filters).to eq(:Host => {21=>"ESX 6.0"}, :StorageProfile => nil)
      end
      it 'clears :placement_storage_profile value' do
        workflow.set_on_vm_id_changed
        values = workflow.instance_variable_get(:@values)
        expect(values[:placement_storage_profile]).to be_nil
      end
    end

    context 'network selection' do
      let(:s11) { FactoryGirl.create(:switch, :name => "A") }
      let(:s12) { FactoryGirl.create(:switch, :name => "B") }
      let(:s13) { FactoryGirl.create(:switch, :name => "C") }
      let(:s14) { FactoryGirl.create(:switch, :name => "DVS14", :shared => true) }
      let(:s15) { FactoryGirl.create(:switch, :name => "DVS15", :shared => true) }
      let(:s21) { FactoryGirl.create(:switch, :name => "DVS21", :shared => true) }

      before do
        @lan11 = FactoryGirl.create(:lan, :name => "lan_A",   :switch_id => s11.id)
        @lan12 = FactoryGirl.create(:lan, :name => "lan_B",   :switch_id => s12.id)
        @lan13 = FactoryGirl.create(:lan, :name => "lan_C",   :switch_id => s13.id)
        @lan14 = FactoryGirl.create(:lan, :name => "lan_DVS", :switch_id => s14.id)
        @lan15 = FactoryGirl.create(:lan, :name => "lan_DVS", :switch_id => s15.id)
        @lan21 = FactoryGirl.create(:lan, :name => "lan_DVS", :switch_id => s21.id)
      end

      it '#allowed_vlans' do
        @host1.switches = [s11, s12, s13]
        allow(workflow).to receive(:allowed_hosts).with(no_args).and_return([workflow.host_to_hash_struct(@host1)])
        vlans, _hosts = workflow.allowed_vlans(:vlans => true, :dvs => true)
        lan_keys   = [@lan11.name, @lan13.name, @lan12.name]
        lan_values = [@lan11.name, @lan13.name, @lan12.name]
        expect(vlans.keys).to match_array(lan_keys)
        expect(vlans.values).to match_array(lan_values)
      end

      it 'concatenates dvswitches of the same portgroup name' do
        @host1.switches = [s11, s12, s13, s14, s15]
        allow(workflow).to receive(:allowed_hosts).with(no_args).and_return([workflow.host_to_hash_struct(@host1)])
        vlans, _hosts = workflow.allowed_vlans(:vlans => true, :dvs => true)
        lan_keys = [@lan11.name, @lan13.name, @lan12.name, "dvs_#{@lan14.name}"]
        switches = [s14.name, s15.name].sort.join('/')
        lan_values = [@lan11.name, @lan13.name, @lan12.name, "#{@lan14.name} (#{switches})"]
        expect(vlans.keys).to match_array(lan_keys)
        expect(vlans.values).to match_array(lan_values)
      end

      it 'concatenates dvswitches of the same portgroup name from different hosts' do
        @host1.switches = [s11, s12, s13, s14, s15]
        @host2.switches = [s15, s21]
        allow(workflow).to receive(:allowed_hosts).with(no_args).and_return(
          [workflow.host_to_hash_struct(@host1), workflow.host_to_hash_struct(@host2)]
        )
        vlans, _hosts = workflow.allowed_vlans(:vlans => true, :dvs => true)
        lan_keys = [@lan11.name, @lan13.name, @lan12.name, "dvs_#{@lan14.name}"]
        switches = [s14.name, s15.name, s21.name].sort.join('/')
        lan_values = [@lan11.name, @lan13.name, @lan12.name, "#{@lan14.name} (#{switches})"]
        expect(vlans.keys).to match_array(lan_keys)
        expect(vlans.values).to match_array(lan_values)
      end

      it 'excludes dvs if told so' do
        @host1.switches = [s11, s12, s13, s14, s15]
        @host2.switches = [s15, s21]
        allow(workflow).to receive(:allowed_hosts).with(no_args).and_return(
          [workflow.host_to_hash_struct(@host1), workflow.host_to_hash_struct(@host2)]
        )
        vlans, _hosts = workflow.allowed_vlans(:vlans => true, :dvs => false)
        lan_keys = [@lan11.name, @lan13.name, @lan12.name]
        expect(vlans.keys).to match_array(lan_keys)
        expect(vlans.values).to match_array(lan_keys)
      end

      it 'concatenates dvswitches of the same portgroup name from different hosts when autoplacement is on' do
        @host1.switches = [s11, s12, s13, s14, s15]
        @host2.switches = [s21]
        workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id, :placement_auto => true)
        vlans, _hosts = workflow.allowed_vlans(:vlans => true, :dvs => true)
        lan_keys = [@lan11.name, @lan13.name, @lan12.name, "dvs_#{@lan14.name}"]
        switches = [s14.name, s15.name, s21.name].sort.join('/')
        lan_values = [@lan11.name, @lan13.name, @lan12.name, "#{@lan14.name} (#{switches})"]
        expect(vlans.keys).to match_array(lan_keys)
        expect(vlans.values).to match_array(lan_values)
      end

      it 'returns no vlans when autoplacement is off and no allowed_hosts' do
        @host1.switches = [s11, s12, s13, s14, s15]
        @host2.switches = [s21]
        workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id, :placement_auto => false)
        vlans, _hosts = workflow.allowed_vlans(:vlans => true, :dvs => true)
        expect(vlans.keys).to match_array([])
        expect(vlans.values).to match_array([])
      end
    end
  end
end
