require "spec_helper"

silence_warnings { ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow.const_set("DIALOGS_VIA_AUTOMATE", false) }

describe ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow do
  let(:admin)    { FactoryGirl.create(:user_with_group) }
  let(:vm_template) { FactoryGirl.create(:template_vmware) }

  before do
    EvmSpecHelper.local_miq_server
  end

  describe "#new" do
    it "pass platform attributes to automate" do
      MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
      MiqAeEngine::MiqAeWorkspaceRuntime.should_receive(:instantiate)
      MiqAeEngine.should_receive(:create_automation_object) do |name, attrs, _options|
        name.should eq("REQUEST")
        attrs.should have_attributes(
          'request'                   => 'UI_PROVISION_INFO',
          'message'                   => 'get_pre_dialog_name',
          'dialog_input_request_type' => 'template',
          'dialog_input_target_type'  => 'vm',
          'platform_category'         => 'infra',
          'platform'                  => 'vmware'
        )
      end

      described_class.new({}, admin.userid)
    end
  end

  describe "#make_request" do
    it "creates and update a request" do
      MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
      MiqAeEngine::MiqAeWorkspaceRuntime.should_receive(:instantiate)

      workflow = described_class.new(values = {}, admin.userid)

      # creates a request

      MiqAeEngine.stub(:resolve_automation_object => double(:root => "x"))

      values.merge!(:src_vm_id => vm_template.id)
      request = workflow.make_request(nil, values, admin.userid)

      expect(request).to be_valid

      # updates a request
      workflow.make_request(request, values, admin.userid)
    end
  end
end
