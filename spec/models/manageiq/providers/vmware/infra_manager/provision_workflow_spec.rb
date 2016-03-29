silence_warnings { ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow.const_set("DIALOGS_VIA_AUTOMATE", false) }

describe ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow do
  include WorkflowSpecHelper

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

  context 'network selection' do
    let(:workflow) { described_class.new({}, admin.userid) }
    before do
      @ems    = FactoryGirl.create(:ems_vmware)
      @host1  = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
      @src_vm = FactoryGirl.create(:vm_vmware, :host => @host1, :ems_id => @ems.id)
      allow(Rbac).to receive(:search) do |hash|
        [Array.wrap(hash[:targets])]
      end
      allow_any_instance_of(VmOrTemplate).to receive(:archived?).with(no_args).and_return(false)
      allow_any_instance_of(VmOrTemplate).to receive(:orphaned?).with(no_args).and_return(false)
      stub_dialog(:get_dialogs)
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id)
      workflow.instance_variable_set(:@target_resource, nil)
    end

    context 'vlans' do
      before do
        s11 = FactoryGirl.create(:switch, :name => "A")
        s12 = FactoryGirl.create(:switch, :name => "B")
        s13 = FactoryGirl.create(:switch, :name => "C")
        @src_vm.host.switches = [s11, s12, s13]
        @lan11 = FactoryGirl.create(:lan, :name => "lan_A", :switch_id => s11.id)
        @lan12 = FactoryGirl.create(:lan, :name => "lan_B", :switch_id => s12.id)
        @lan13 = FactoryGirl.create(:lan, :name => "lan_C", :switch_id => s13.id)
      end

      it '#allowed_vlans' do
        allow(workflow).to receive(:allowed_hosts).with(no_args).and_return([workflow.host_to_hash_struct(@host1)])
        vlans = workflow.allowed_vlans(:vlans => true, :dvs => false)
        lan_keys = [@lan11.name, @lan13.name, @lan12.name]
        expect(vlans.keys).to match_array(lan_keys)
        expect(vlans.values).to match_array(lan_keys)
      end
    end

    context 'dvs' do
      before do
        @host1_dvs = {'pg1' => ['switch1'], 'pg2' => ['switch2']}
        @host1_dvs_hash = {'dvs_pg1' => 'pg1 (switch1)',
                           'dvs_pg2' => 'pg2 (switch2)'}
        allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive(:connect)
        allow(workflow).to receive(:get_host_dvs).with(@host1, nil).and_return(@host1_dvs)
      end

      it '#allowed_dvs single host' do
        workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id,
                                      :host_id => @host1.id)
        workflow.instance_variable_set(:@target_resource,
                                       :host    => workflow.host_to_hash_struct(@host1),
                                       :ems     => workflow.ci_to_hash_struct(@ems),
                                       :host_id => @host1.id)
        dvs = workflow.allowed_dvs({}, nil)
        expect(dvs).to eql(@host1_dvs_hash)
      end

      context "#allowed_dvs" do
        before do
          @host2 = FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
          @host2_dvs = {'pg1' => ['switch21'], 'pg2' => ['switch2'], 'pg3' => ['switch23']}
          allow(workflow).to receive(:get_host_dvs).with(@host2, nil).and_return(@host2_dvs)
          workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id,
                                        :placement_auto => true)

          @combined_dvs_hash = {'dvs_pg1' => 'pg1 (switch1/switch21)',
                                'dvs_pg2' => 'pg2 (switch2)',
                                'dvs_pg3' => 'pg3 (switch23)'}
        end

        it 'multiple hosts auto placement' do
          dvs = workflow.allowed_dvs({}, nil)
          expect(dvs).to eql(@combined_dvs_hash)
        end

        it 'cached filtering' do
          # Cache the dvs for 2 hosts
          workflow.allowed_dvs({}, nil)

          workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id,
                                        :placement_auto => false)
          workflow.instance_variable_set(:@target_resource,
                                         :host    => workflow.host_to_hash_struct(@host1),
                                         :ems     => workflow.ci_to_hash_struct(@ems),
                                         :host_id => @host1.id)
          dvs = workflow.allowed_dvs({}, nil)
          expect(dvs).to eql(@host1_dvs_hash)
        end
      end
    end
  end
end
