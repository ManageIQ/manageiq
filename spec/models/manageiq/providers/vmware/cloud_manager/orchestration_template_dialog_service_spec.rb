require Rails.root.join('spec/shared/services/assert_dialog_field')
RSpec.configure { |c| c.include Helpers }

describe ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplateDialogService do
  let(:template_vapp) { FactoryGirl.create(:orchestration_template_vmware_cloud_with_content) }

  describe "#create_dialog" do
    it "creates a dialog from VMware vCloud vApp template with stack basic info and parameters" do
      dialog = subject.create_dialog("test", template_vapp)

      tabs = dialog.dialog_tabs
      expect(tabs[0].dialog_groups.size).to eq(2)
      assert_vmware_cloud_stack_group(tabs[0].dialog_groups[0])
      assert_vmware_cloud_parameters_group(tabs[0].dialog_groups[1])
    end
  end


  def assert_vmware_cloud_stack_group(group)
    fields = group.dialog_fields
    expect(fields.size).to eq(3)

    expect(fields[0].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Tenants")
    assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name",       :dynamic => true)
    assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",        :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
    expect(fields[2].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Availability_Zones")
    assert_field(fields[2], DialogFieldDropDownList, :name => "availability_zone", :dynamic => true)
  end

  def assert_vmware_cloud_parameters_group(group)
    expect(group).to have_attributes(
      :label   => "vApp Parameters",
      :display => "edit",
    )

    fields = group.dialog_fields
    expect(fields.size).to eq(2)

    assert_field(fields[0], DialogFieldCheckBox, :name => "param_deploy",  :default_value => "t", :data_type => "boolean")
    assert_field(fields[1], DialogFieldCheckBox, :name => "param_powerOn", :default_value => "f", :data_type => "boolean")
  end
end
