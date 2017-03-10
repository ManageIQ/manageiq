describe OrchestrationTemplateDialogService do
  let(:dialog_service) { described_class.new }
  let(:template_hot)   { FactoryGirl.create(:orchestration_template_hot_with_content) }
  let(:template_azure) { FactoryGirl.create(:orchestration_template_azure_with_content) }
  let(:empty_template) { FactoryGirl.create(:orchestration_template_cfn) }
  let(:template_vapp)  { FactoryGirl.create(:orchestration_template_vmware_cloud_with_content) }

  describe "#create_dialog" do
    it "creates a dialog from hot template with stack basic info and parameters" do
      dialog = dialog_service.create_dialog("test", template_hot)

      expect(dialog).to have_attributes(
        :label   => "test",
        :buttons => "submit,cancel"
      )

      tabs = dialog.dialog_tabs
      expect(tabs.size).to eq(1)
      assert_stack_tab(tabs[0])
    end

    it "creates a dialog from azure template with stack basic info and parameters" do
      dialog = dialog_service.create_dialog("test", template_azure)

      tabs = dialog.dialog_tabs
      assert_tab_attributes(tabs[0])
      assert_azure_stack_group(tabs[0].dialog_groups[0])
    end

    it "creates a dialog from a template without parameters" do
      dialog = dialog_service.create_dialog("test", empty_template)

      tabs = dialog.dialog_tabs
      assert_tab_attributes(tabs[0])
      assert_aws_openstack_stack_group(tabs[0].dialog_groups[0])
    end

    it "creates a dialog from VMware vCloud vApp template with stack basic info and parameters" do
      dialog = dialog_service.create_dialog("test", template_vapp)

      tabs = dialog.dialog_tabs
      assert_tab_attributes(tabs[0])
      expect(tabs[0].dialog_groups.size).to eq(2)
      assert_vmware_cloud_stack_group(tabs[0].dialog_groups[0])
      assert_vmware_cloud_parameters_group(tabs[0].dialog_groups[1])
    end
  end

  def assert_stack_tab(tab)
    assert_tab_attributes(tab)

    groups = tab.dialog_groups
    expect(groups.size).to eq(3)

    assert_aws_openstack_stack_group(groups[0])
    assert_parameter_group1(groups[1])
    assert_parameter_group2(groups[2])
  end

  def assert_tab_attributes(tab)
    expect(tab).to have_attributes(
      :label   => "Basic Information",
      :display => "edit"
    )
  end

  def assert_aws_openstack_stack_group(group)
    expect(group).to have_attributes(
      :label   => "Options",
      :display => "edit",
    )

    fields = group.dialog_fields
    expect(fields.size).to eq(4)

    expect(fields[0].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Tenants")
    assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name",     :dynamic => true)
    assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",      :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
    assert_field(fields[2], DialogFieldDropDownList, :name => "stack_onfailure", :values => [[nil, "<Choose>"], %w(DO_NOTHING Do\ nothing), %w(ROLLBACK Rollback)])
    assert_field(fields[3], DialogFieldTextBox,      :name => "stack_timeout",   :data_type => 'integer')
  end

  def assert_azure_stack_group(group)
    expect(group).to have_attributes(
      :label   => "Options",
      :display => "edit",
    )

    fields = group.dialog_fields
    expect(fields.size).to eq(5)

    expect(fields[0].resource_action.fqname).to eq("/Cloud/Orchestration/Operations/Methods/Available_Tenants")
    assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name",        :dynamic => true)
    assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",         :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
    assert_field(fields[2], DialogFieldDropDownList, :name => "resource_group",     :dynamic => true)
    assert_field(fields[3], DialogFieldTextBox,      :name => "new_resource_group", :validator_rule => '^[A-Za-z][A-Za-z0-9\-_]*$')

    mode_values = [[nil,           "<Choose>"],
                   ["Complete",    "Complete (Delete other resources in the group)"],
                   ["Incremental", "Incremental (Default)"]]
    assert_field(fields[4], DialogFieldDropDownList, :name => "deploy_mode", :values => mode_values)
    expect(fields[4].default_value).to eq("Incremental")
  end

  def assert_vmware_cloud_stack_group(group)
    expect(group).to have_attributes(
      :label   => "Options",
      :display => "edit",
    )

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

  def assert_field(field, clss, attributes)
    expect(field).to be_kind_of clss
    expect(field).to have_attributes(attributes)
  end

  def assert_parameter_group1(group)
    expect(group).to have_attributes(
      :label   => "General parameters",
      :display => "edit",
    )

    fields = group.dialog_fields
    expect(fields.size).to eq(3)

    assert_field(fields[0], DialogFieldTextBox,      :name => "param_flavor",     :default_value => "m1.small")
    assert_field(fields[1], DialogFieldDropDownList, :name => "param_image_id",   :default_value => "F18-x86_64-cfntools", :values => [[nil, "<Choose>"], %w(F18-i386-cfntools F18-i386-cfntools), %w(F18-x86_64-cfntools F18-x86_64-cfntools)])
    assert_field(fields[2], DialogFieldTextBox,      :name => "param_cartridges", :default_value => "cron,diy,haproxy,mysql,nodejs,perl,php,postgresql,python,ruby")
  end

  def assert_parameter_group2(group)
    expect(group).to have_attributes(
      :label   => "Parameter Group2",
      :display => "edit",
    )

    fields = group.dialog_fields
    expect(fields.size).to eq(3)

    assert_field(fields[0], DialogFieldTextBox,     :name => "param_admin_pass", :validator_rule => '[a-zA-Z0-9]+')
    assert_field(fields[1], DialogFieldTextBox,     :name => "param_db_port",    :label => 'Port Number')
    assert_field(fields[2], DialogFieldTextAreaBox, :name => "param_metadata")
  end
end
