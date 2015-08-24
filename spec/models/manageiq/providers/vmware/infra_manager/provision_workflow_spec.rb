require "spec_helper"

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
      assert_automate_dialog_lookup("infra", "vmware", "get_pre_dialog_name", nil)

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
      workflow = described_class.new(values = {:running_pre_dialog => false}, admin.userid)

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

      request = workflow.make_request(nil, values, admin.userid) # TODO: nil

      expect(request).to be_valid
      expect(request).to be_a_kind_of(MiqProvisionRequest)
      expect(request.request_type).to eq("template")
      expect(request.description).to eq("Provision from [#{template.name}] to [New VM]")
      expect(request.requester).to eq(admin)
      expect(request.userid).to eq(admin.userid)
      expect(request.requester_name).to eq(admin.name)

      # updates a request

      stub_get_next_vm_name

      workflow = described_class.new(values, alt_user.userid)

      expect(AuditEvent).to receive(:success).with(
        :event        => "vm_provision_request_updated",
        :target_class => "Vm",
        :userid       => alt_user.userid,
        :message      => "VM Provisioning request updated by <#{alt_user.userid}> for Vm:#{template.id}"
      )
      workflow.make_request(request, values, alt_user.userid)
    end

    it '#get_cpu_values_hash' do
      template = FactoryGirl.create(:template_vmware, :name => "test_template")
      FactoryGirl.create(:hardware, :vm_or_template => template, :cores_per_socket => 4, :logical_cpus => 8, :numvcpus => 2)
      wf = described_class.new({}, admin.userid)
      result = wf.get_cpu_values_hash(template)

      expect(result[:number_of_cpus]).to    eq(8)
      expect(result[:number_of_sockets]).to eq(2)
      expect(result[:cores_per_socket]).to  eq(4)
    end
  end
end
