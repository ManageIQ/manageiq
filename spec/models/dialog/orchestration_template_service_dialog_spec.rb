describe Dialog::OrchestrationTemplateServiceDialog do
  let(:orchestration_template) do
    FactoryGirl.create(:orchestration_template).tap do |template|
      allow(template).to receive(:parameter_groups).and_return(param_groups)
    end
  end
  let(:param_groups) { create_parameters(param_options) }
  let(:dialog) { described_class.create_dialog("test", orchestration_template) }

  describe ".create_dialog" do
    let(:param_groups) { [] }

    it "creates a dialog from a template without parameters" do
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
      let(:param_options) do
        constraint = OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => %w(val1 val2), :allow_multiple => true)
        {:default_value => '["val1"]', :constraints => [constraint]}
      end

      it "creates a dropdown field with pairs of values" do
        assert_field(test_field(dialog),
                     DialogFieldDropDownList,
                     :name              => "param_user",
                     :default_value     => "[\"val1\"]",
                     :values            => [%w(val1 val1), %w(val2 val2)],
                     :reconfigurable    => true,
                     :force_multi_value => true)
      end
    end

    context "when a hash of allowed values is given" do
      let(:param_options) do
        constraint = OrchestrationTemplate::OrchestrationParameterAllowed.new(:allowed_values => {"key1" => "val1", "key2" => "val2"})
        {:default_value => 'val1', :constraints => [constraint]}
      end

      it "creates pairs from hashes" do
        assert_field(test_field(dialog),
                     DialogFieldDropDownList,
                     :name          => "param_user",
                     :default_value => "val1",
                     :values        => [[nil, "<Choose>"], %w(key1 val1), %w(key2 val2)])
      end
    end

    context "when automate method is given" do
      let(:param_options) do
        constraint = OrchestrationTemplate::OrchestrationParameterAllowedDynamic.new(:fqname => "/Path/To/Method")
        {:constraints => [constraint]}
      end

      it "creates a dropdown field requested resource_action" do
        field = test_field(dialog)
        expect(field.resource_action.fqname).to eq("/Path/To/Method")
        assert_field(field, DialogFieldDropDownList, :name => "param_user")
      end
    end
  end

  context "creation of checkbox parameter field" do
    let(:param_options) do
      constraint = OrchestrationTemplate::OrchestrationParameterBoolean.new
      {:default_value => true, :constraints => [constraint]}
    end

    it "creates a checkbox field" do
      assert_field(test_field(dialog), DialogFieldCheckBox, :data_type => 'boolean', :default_value => 't')
    end
  end

  describe "creation of textarea parameter field" do
    let(:param_options) do
      constraint = OrchestrationTemplate::OrchestrationParameterMultiline.new
      {:constraints => [constraint]}
    end

    it "creates a textarea field" do
      assert_field(test_field(dialog), DialogFieldTextAreaBox, :name => 'param_user')
    end
  end

  describe "creation of textbox parameter field" do
    let(:param_options) { {:data_type => 'integer', :default_value => 2} }

    it "creates a textarea field" do
      assert_field(test_field(dialog), DialogFieldTextBox, :data_type => 'integer', :default_value => '2')
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

  def test_field(dialog)
    # First ensure that the dialog is properly constructed.
    tabs = dialog.dialog_tabs
    expect(tabs.size).to eq(1)
    expect(tabs[0].dialog_groups.size).to eq(2)
    expect(tabs[0].dialog_groups[1].dialog_fields.size).to eq(1)
    fields = tabs[0].dialog_groups[1].dialog_fields
    # Return the first field; it should be the only field.
    fields[0]
  end

  def create_parameters(options)
    options.reverse_merge!(:name => 'user', :label => 'User Parameter', :data_type => 'string', :required => true)
    [OrchestrationTemplate::OrchestrationParameterGroup.new(:label => 'group', :parameters => [OrchestrationTemplate::OrchestrationParameter.new(options)])]
  end
end
