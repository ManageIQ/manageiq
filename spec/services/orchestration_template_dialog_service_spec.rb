require Rails.root.join('spec/shared/services/assert_dialog_field')
RSpec.configure { |c| c.include Helpers }

describe OrchestrationTemplateDialogService do
  let(:empty_template) { FactoryGirl.create(:orchestration_template) }

  describe "creating of stack option tab" do
    before do
      allow(empty_template).to receive(:parameter_groups).and_return([1, 2].collect do |n|
        OrchestrationTemplate::OrchestrationParameterGroup.new(
          :label      => "Parameter Group#{n}",
          :parameters => [OrchestrationTemplate::OrchestrationParameter.new(
            :name      => "param#{n}",
            :label     => "Parameter",
            :data_type => "string")
          ])
      end)
    end

    it "creates a dialog with stack basic info and common options and parameters" do
      dialog = subject.create_dialog("test", empty_template)

      expect(dialog).to have_attributes(:label => "test", :buttons => "submit,cancel")

      tabs = dialog.dialog_tabs
      expect(tabs.size).to eq(1)
      assert_dialog_attributes(tabs[0], "Basic Information")

      groups = tabs[0].dialog_groups
      expect(groups.size).to eq(3)
      assert_stack_option_group(groups[0])
      assert_parameter_group(groups[1], '1')
      assert_parameter_group(groups[2], '2')
    end
  end

  describe "creation of dropdown parameter fields" do
    context "when allowed values are given" do
      before do
        # Create a simple dialog with one dropdown parameter.
        constraint = OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => %w(val1 val2))
        param_groups = create_dropdown_param(constraint)
        allow(empty_template).to receive(:parameter_groups).and_return(param_groups)
      end

      it "creates a dropdown field with pairs of values" do
        dialog = subject.create_dialog("test", empty_template)

        # Get the dropdown field
        field = dropdown_field(dialog)
        # Ensure the allowed values are properly stored.
        assert_field(field, DialogFieldDropDownList, :name => "param_dropdown", :default_value => "val1", :values => [%w(val1 val1), %w(val2 val2)])
      end
    end

    context "when a hash of allowed values is given" do
      before do
        # Create a simple dialog with one dropdown parameter.
        constraint = OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => {"key1" => "val1", "key2" => "val2"})
        param_groups = create_dropdown_param(constraint)
        allow(empty_template).to receive(:parameter_groups).and_return(param_groups)
      end

      it "creates pairs from hashes" do
        dialog = subject.create_dialog("test", empty_template)

        # Get the dropdown field
        field = dropdown_field(dialog)
        # Ensure the allowed values are properly stored.
        assert_field(field, DialogFieldDropDownList, :name => "param_dropdown", :default_value => "val1", :values => [%w(key1 val1), %w(key2 val2)])
      end
    end

    context "when automate method is given" do
      before do
        # Create a simple dialog with one dropdown parameter.
        constraint = OrchestrationTemplate::OrchestrationParameterAllowedDynamic.new(:fqname => "/Path/To/Method")
        param_groups = create_dropdown_param(constraint)
        allow(empty_template).to receive(:parameter_groups).and_return(param_groups)
      end

      it "creates a dropdown field requested resource_action" do
        dialog = subject.create_dialog("test", empty_template)

        # Get the dropdown field
        field = dropdown_field(dialog)
        # Ensure the field is properly defined with the resource action.
        expect(field.resource_action.fqname).to eq("/Path/To/Method")
        assert_field(field, DialogFieldDropDownList, :name => "param_dropdown")
      end
    end
  end

  def assert_dialog_attributes(component, label)
    expect(component).to have_attributes(:label => label, :display => "edit")
  end

  def assert_stack_option_group(group)
    assert_dialog_attributes(group, "Options")

    fields = group.dialog_fields
    expect(fields.size).to eq(2)

    expect(fields[0].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Tenants")
    assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name", :dynamic => true)
    assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",  :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
  end

  def assert_parameter_group(group, id)
    assert_dialog_attributes(group, "Parameter Group#{id}")

    fields = group.dialog_fields
    expect(fields.size).to eq(1)
    assert_field(fields[0], DialogFieldTextBox, :name => "param_param#{id}")
  end

  def dropdown_field(dialog)
    # First ensure that the dialog is properly constructed.
    tabs = dialog.dialog_tabs
    expect(tabs.size).to eq(1)
    expect(tabs[0].dialog_groups.size).to eq(2)
    expect(tabs[0].dialog_groups[1].dialog_fields.size).to eq(1)
    fields = tabs[0].dialog_groups[1].dialog_fields
    # Return the first field; it should be the only field.
    fields[0]
  end

  def create_dropdown_param(constraint)
    [OrchestrationTemplate::OrchestrationParameterGroup.new(
      :label      => "group",
      :parameters => [
        OrchestrationTemplate::OrchestrationParameter.new(
          :name          => "dropdown",
          :label         => "Drop down",
          :data_type     => "string",
          :default_value => "val1",
          :constraints   => [constraint])
      ])
    ]
  end
end
