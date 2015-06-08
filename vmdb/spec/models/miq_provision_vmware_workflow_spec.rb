require "spec_helper"

silence_warnings { MiqProvisionVmwareWorkflow.const_set("DIALOGS_VIA_AUTOMATE", false) }

describe MiqProvisionVmwareWorkflow do
  before do
    MiqRegion.seed
  end

  context "with a user" do
    let(:admin)    { FactoryGirl.create(:user, :name => 'admin', :userid => 'admin') }

    before do
      MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
    end

    it "pass platform attributes to automate" do
      MiqAeEngine.should_receive(:resolve_automation_object)
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

      MiqProvisionVmwareWorkflow.new({}, admin.userid)
    end
  end
end
