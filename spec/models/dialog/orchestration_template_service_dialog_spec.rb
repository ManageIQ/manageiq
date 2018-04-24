describe Dialog::OrchestrationTemplateServiceDialog do
  before(:each) do
    Rails.cache.clear
  end

  let(:orchestration_template) do
    FactoryGirl.create(:orchestration_template).tap do |template|
      allow(template).to receive(:parameter_groups).and_return(param_groups)
    end
  end
  let(:orchestration_template_tabs) do
    FactoryGirl.create(:orchestration_template).tap do |template|
      allow(template).to receive(:parameter_groups_tabbed).and_return(param_groups_tabbed)
    end
  end
  let(:param_groups) { create_parameters(param_options) }
  let(:param_groups_tabbed) { create_parameter_groups_tabbed }
  let(:dialog) { described_class.create_dialog("test", orchestration_template) }
  let(:dialog_tabbed) { described_class.create_dialog("test_tabbed", orchestration_template_tabs) }

  describe ".create_dialog" do
    let(:param_groups) { [] }

    it "creates a dialog from a template without parameters" do
      expect(dialog).to have_attributes(
        :label   => "test",
        :buttons => "submit,cancel"
      )

      tabs = dialog.dialog_tabs
      assert_tab_attributes(tabs[0], :label => "Basic Information", :display => "edit")
    end
  end

  describe ".create_dialog_tabbed" do
    it "creates a dialog with tabs from a template" do
      expect(dialog_tabbed).not_to be_nil
      tabs = dialog_tabbed.dialog_tabs

      expect(tabs).not_to be_nil
      expect(tabs.length).to be 3

      assert_tab_attributes(tabs[0], :label => "Basic Information", :display => "edit")
      assert_tab_attributes(tabs[1], :label => "Networks", :display => "edit")
      assert_tab_attributes(tabs[2], :label => "VMs", :display => "edit")

      expect(tabs[0].dialog_groups.length).to be 2
      expect(tabs[1].dialog_groups.length).to be 1
      expect(tabs[2].dialog_groups.length).to be 1

      expect(tabs[0].dialog_groups[0].dialog_fields.length).to be 4
      expect(tabs[0].dialog_groups[1].dialog_fields.length).to be 1
      expect(tabs[1].dialog_groups[0].dialog_fields.length).to be 1
      expect(tabs[2].dialog_groups[0].dialog_fields.length).to be 1

      assert_stack_group(tabs[0].dialog_groups[0])

      assert_field(tabs[0].dialog_groups[1].dialog_fields[0],
                   DialogFieldCheckBox,
                   :name          => 'param_deploy',
                   :label         => 'Deploy vApp',
                   :data_type     => 'boolean',
                   :default_value => "t")

      assert_field(tabs[1].dialog_groups[0].dialog_fields[0],
                   DialogFieldTextBox,
                   :name      => 'param_parent-0',
                   :label     => 'Parent Network',
                   :data_type => 'string',)

      assert_field(tabs[2].dialog_groups[0].dialog_fields[0],
                   DialogFieldTextBox,
                   :name          => 'param_instance_name-0',
                   :label         => 'Instance name',
                   :data_type     => 'string',
                   :required      => true,
                   :default_value => 'default_name')
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
    assert_tab_attributes(tab, :label => "Basic Information", :display => "edit")

    groups = tab.dialog_groups
    expect(groups.size).to eq(3)

    assert_stack_group(groups[0])
  end

  def assert_tab_attributes(tab, attributes)
    expect(tab).to have_attributes(attributes)
  end

  def assert_stack_group(group)
    expect(group).to have_attributes(
      :label   => "Options",
      :display => "edit",
    )

    fields = group.dialog_fields
    expect(fields.size).to eq(4)

    expect(fields[0].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Tenants")
    assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name", :dynamic => true, :reconfigurable => nil)
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

  def create_parameter_groups_tabbed
    [
      {
        :title       => "Basic Information",
        :stack_group => [
          OrchestrationTemplate::OrchestrationParameter.new(
            :name           => "tenant_name",
            :label          => "Tenant",
            :data_type      => "string",
            :description    => "Tenant where the stack will be deployed",
            :required       => true,
            :reconfigurable => false,
            :constraints    => [
              OrchestrationTemplate::OrchestrationParameterAllowedDynamic.new(
                :fqname => "/Cloud/Orchestration/Operations/Methods/Available_Tenants"
              )
            ]
          ),
          OrchestrationTemplate::OrchestrationParameter.new(
            :name           => "stack_name",
            :label          => "Stack Name",
            :data_type      => "string",
            :description    => "Name of the stack",
            :required       => true,
            :reconfigurable => false,
            :constraints    => [
              OrchestrationTemplate::OrchestrationParameterPattern.new(
                :pattern => '^[A-Za-z][A-Za-z0-9\-]*$'
              )
            ]
          ),
          OrchestrationTemplate::OrchestrationParameter.new(
            :name           => "availability_zone",
            :label          => "Availability zone",
            :data_type      => "string",
            :description    => "Availability zone where the stack will be deployed",
            :reconfigurable => false,
          ),
          OrchestrationTemplate::OrchestrationParameter.new(
            :name           => 'stack_template',
            :label          => 'vApp Template',
            :description    => 'vApp Template that this Service bases on',
            :data_type      => 'string',
            :required       => true,
            :reconfigurable => false
          )
        ],
        :param_group => [OrchestrationTemplate::OrchestrationParameterGroup.new(
          :label      => 'vApp Parameters',
          :parameters => [
            OrchestrationTemplate::OrchestrationParameter.new(
              :name          => 'deploy',
              :label         => 'Deploy vApp',
              :data_type     => 'boolean',
              :default_value => true,
              :constraints   => [
                OrchestrationTemplate::OrchestrationParameterBoolean.new
              ]
            )
          ],
        )]
      },
      {
        :title       => "Networks",
        :param_group => [OrchestrationTemplate::OrchestrationParameterGroup.new(
          :label      => 'tab2_group',
          :parameters => [
            OrchestrationTemplate::OrchestrationParameter.new(
              :name      => 'parent-0',
              :label     => 'Parent Network',
              :data_type => 'string',
            )
          ]
        )]
      },
      {
        :title       => "VMs",
        :param_group => [OrchestrationTemplate::OrchestrationParameterGroup.new(
          :label      => 'tab3_group',
          :parameters => [
            OrchestrationTemplate::OrchestrationParameter.new(
              :name          => 'instance_name-0',
              :label         => 'Instance name',
              :data_type     => 'string',
              :required      => true,
              :default_value => 'default_name'
            )
          ]
        )]
      }
    ]
  end
end
