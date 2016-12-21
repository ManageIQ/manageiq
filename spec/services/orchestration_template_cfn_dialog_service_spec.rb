require Rails.root.join('spec/shared/services/assert_dialog_field')
RSpec.configure { |c| c.include Helpers }

describe OrchestrationTemplateCfnDialogService do
  let(:empty_template) do
    FactoryGirl.create(:orchestration_template).tap { |t| allow(t).to receive(:parameter_groups).and_return([]) }
  end

  describe "#create_dialog" do
    it "creates a dialog with AWS stack options" do
      dialog = subject.create_dialog("test", empty_template)
      tabs = dialog.dialog_tabs
      group = tabs[0].dialog_groups[0] # stack options group
      fields = group.dialog_fields
      expect(fields.size).to eq(4)

      expect(fields[0].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Tenants")
      assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name",     :dynamic => true)
      assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",      :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
      assert_field(fields[2], DialogFieldDropDownList, :name => "stack_onfailure", :values => [%w(DO_NOTHING Do\ nothing), %w(ROLLBACK Rollback)])
      assert_field(fields[3], DialogFieldTextBox,      :name => "stack_timeout",   :data_type => 'integer')
    end
  end
end
