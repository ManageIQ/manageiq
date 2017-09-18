describe Dialog::OrchestrationTemplateServiceDialog do
  let(:orchestration_template) { FactoryGirl.create(:orchestration_template) }

  describe "#create_dialog" do
    it "creates a dialog from a template without parameters" do
      allow(orchestration_template).to receive(:parameter_groups).and_return([])
      dialog = subject.create_dialog("test", orchestration_template)

      expect(dialog).to have_attributes(
        :label   => "test",
        :buttons => "submit,cancel"
      )

      tabs = dialog.dialog_tabs
      assert_tab_attributes(tabs[0])
    end
  end

  describe "creation of dropdown parameter fields" do
    context "when allowed values are given" do
      it "creates a dropdown field with pairs of values" do
        # Create a simple dialog with one dropdown parameter.
        constraint = OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => %w(val1 val2))
        param_groups = create_dropdown_param(constraint)
        allow(orchestration_template).to receive(:parameter_groups).and_return(param_groups)
        dialog = subject.create_dialog("test", orchestration_template)

        # Get the dropdown field
        field = dropdown_field(dialog)
        # Ensure the allowed values are properly stored.
        assert_field(field, DialogFieldDropDownList, :name => "param_dropdown", :default_value => "val1", :values => [%w(val1 val1), %w(val2 val2)], :reconfigurable => true)
      end
    end

    context "when a hash of allowed values is given" do
      it "creates pairs from hashes" do
        # Create a simple dialog with one dropdown parameter.
        constraint = OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => {"key1" => "val1", "key2" => "val2"})
        param_groups = create_dropdown_param(constraint)
        allow(orchestration_template).to receive(:parameter_groups).and_return(param_groups)
        dialog = subject.create_dialog("test", orchestration_template)

        # Get the dropdown field
        field = dropdown_field(dialog)
        # Ensure the allowed values are properly stored.
        assert_field(field, DialogFieldDropDownList, :name => "param_dropdown", :default_value => "val1", :values => [[nil, "<Choose>"], %w(key1 val1), %w(key2 val2)])
      end
    end

    context "when automate method is given" do
      it "creates a dropdown field requested resource_action" do
        # Create a simple dialog with one dropdown parameter.
        constraint = OrchestrationTemplate::OrchestrationParameterAllowedDynamic.new(:fqname => "/Path/To/Method")
        param_groups = create_dropdown_param(constraint)
        allow(orchestration_template).to receive(:parameter_groups).and_return(param_groups)
        dialog = subject.create_dialog("test", orchestration_template)

        # Get the dropdown field
        field = dropdown_field(dialog)
        # Ensure the field is properly defined with the resource action.
        expect(field.resource_action.fqname).to eq("/Path/To/Method")
        assert_field(field, DialogFieldDropDownList, :name => "param_dropdown")
      end
    end
  end

  def assert_stack_tab(tab)
    assert_tab_attributes(tab)

    groups = tab.dialog_groups
    expect(groups.size).to eq(3)

    assert_stack_group(groups[0])
  end

  def assert_tab_attributes(tab)
    expect(tab).to have_attributes(
      :label   => "Basic Information",
      :display => "edit"
    )
  end

  def assert_stack_group(group)
    expect(group).to have_attributes(
      :label   => "Options",
      :display => "edit",
    )

    fields = group.dialog_fields
    expect(fields.size).to eq(4)

    expect(fields[0].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Tenants")
    assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name", :dynamic => true, :reconfigurable => false)
    assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",  :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$', :reconfigurable => false)
  end

  def assert_field(field, clss, attributes)
    expect(field).to be_kind_of clss
    expect(field).to have_attributes(attributes)
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
          :required      => true,
          :constraints   => [constraint]
        )
      ]
    )]
  end
end
