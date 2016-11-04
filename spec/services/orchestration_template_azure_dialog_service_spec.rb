require Rails.root.join('spec/shared/services/assert_dialog_field')
RSpec.configure { |c| c.include Helpers }

describe OrchestrationTemplateAzureDialogService do
  let(:empty_template) do
    FactoryGirl.create(:orchestration_template).tap { |t| allow(t).to receive(:parameter_groups).and_return([]) }
  end

  describe "#create_dialog" do
    it "creates a dialog with Azure stack options" do
      dialog = subject.create_dialog("test", empty_template)
      tabs = dialog.dialog_tabs
      group = tabs[0].dialog_groups[0] # stack options group
      fields = group.dialog_fields
      expect(fields.size).to  eq(5)

      expect(fields[0].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Tenants")
      assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name",        :dynamic => true)
      assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",         :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
      assert_field(fields[2], DialogFieldDropDownList, :name => "resource_group",     :dynamic => true)
      assert_field(fields[3], DialogFieldTextBox,      :name => "new_resource_group", :validator_rule => '^[A-Za-z][A-Za-z0-9\-_]*$')

      mode_values = [["Complete",    "Complete (Delete other resources in the group)"],
                     ["Incremental", "Incremental (Default)"]]
      assert_field(fields[4], DialogFieldDropDownList, :name => "deploy_mode", :values => mode_values)
      expect(fields[4].default_value).to eq("Incremental")
    end
  end
end
