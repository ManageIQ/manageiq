require "spec_helper"

describe MiqProvisionMicrosoftWorkflow do
  before do
    MiqRegion.seed
  end

  context "With a Valid Template," do
    let(:admin)    { FactoryGirl.create(:user, :name => 'admin', :userid => 'admin') }
    let(:provider) { FactoryGirl.create(:ems_microsoft) }
    let(:template) { FactoryGirl.create(:template_microsoft, :name => "template", :ext_management_system => provider) }

    before do
      MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})
      MiqProvisionMicrosoftWorkflow.any_instance.stub(:update_field_visibility)
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
          'platform'                  => 'microsoft'
        )
      end

      MiqProvisionMicrosoftWorkflow.new({}, admin.userid)
    end

    context "#allowed_vlans" do
      let(:workflow) { MiqProvisionMicrosoftWorkflow.new({:src_vm_id => template.id}, admin.userid) }

      before do
        @host   = FactoryGirl.create(:host_microsoft, :ext_management_system => provider)
        @vswitch = FactoryGirl.create(:switch, :name => 'vSwitch0', :ports => 32, :host => @host)

        workflow.stub(:get_selected_hosts).and_return([@host])
      end

      it "should return a vlan name" do
        vlans = workflow.allowed_vlans
        vlans.keys.should match_array [@vswitch.name]
      end
    end
  end
end
