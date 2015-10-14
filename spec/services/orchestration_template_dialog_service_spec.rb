require "spec_helper"

describe OrchestrationTemplateDialogService do
  let(:dialog_service) { described_class.new }
  let(:template_hot)   { FactoryGirl.create(:orchestration_template_hot_with_content) }
  let(:template_azure) { FactoryGirl.create(:orchestration_template_azure_with_content) }
  let(:empty_template) { FactoryGirl.create(:orchestration_template_cfn) }

  describe "#create_dialog" do
    it "creates a dialog from hot template with stack basic info and parameters" do
      dialog = dialog_service.create_dialog("test", template_hot)

      dialog.should have_attributes(
        :label   => "test",
        :buttons => "submit,cancel"
      )

      tabs = dialog.dialog_tabs
      tabs.size.should == 1
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
  end

  def assert_stack_tab(tab)
    assert_tab_attributes(tab)

    groups = tab.dialog_groups
    groups.size.should == 3

    assert_aws_openstack_stack_group(groups[0])
    assert_parameter_group1(groups[1])
    assert_parameter_group2(groups[2])
  end

  def assert_tab_attributes(tab)
    tab.should have_attributes(
      :label   => "Basic Information",
      :display => "edit"
    )
  end

  def assert_aws_openstack_stack_group(group)
    group.should have_attributes(
      :label   => "Options",
      :display => "edit",
    )

    fields = group.dialog_fields
    fields.size.should == 4

    fields[0].resource_action.fqname.should == "/Cloud/Orchestration/Operations/Methods/Available_Tenants"
    assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name",     :dynamic => true)
    assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",      :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
    assert_field(fields[2], DialogFieldDropDownList, :name => "stack_onfailure", :values => [%w(DO_NOTHING Do\ nothing), %w(ROLLBACK Rollback)])
    assert_field(fields[3], DialogFieldTextBox,      :name => "stack_timeout",   :validator_rule => '^[1-9][0-9]*$')
  end

  def assert_azure_stack_group(group)
    group.should have_attributes(
      :label   => "Options",
      :display => "edit",
    )

    fields = group.dialog_fields
    fields.size.should == 4

    fields[0].resource_action.fqname.should == "/Cloud/Orchestration/Operations/Methods/Available_Tenants"
    assert_field(fields[0], DialogFieldDropDownList, :name => "tenant_name",    :dynamic => true)
    assert_field(fields[1], DialogFieldTextBox,      :name => "stack_name",     :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
    assert_field(fields[2], DialogFieldTextBox,      :name => "resource_group", :validator_rule => '^[A-Za-z][A-Za-z0-9\-_]*$')
    assert_field(fields[3], DialogFieldDropDownList, :name => "deploy_mode",    :values => [%w(Complete Complete), %w(Incremental Incremental)])
  end

  def assert_field(field, clss, attributes)
    field.should be_kind_of clss
    field.should have_attributes(attributes)
  end

  def assert_parameter_group1(group)
    group.should have_attributes(
      :label   => "General parameters",
      :display => "edit",
    )

    fields = group.dialog_fields
    fields.size.should == 3

    assert_field(fields[0], DialogFieldTextBox,      :name => "param_flavor",     :default_value => "m1.small")
    assert_field(fields[1], DialogFieldDropDownList, :name => "param_image_id",   :default_value => "F18-x86_64-cfntools", :values => [%w(F18-i386-cfntools F18-i386-cfntools), %w(F18-x86_64-cfntools F18-x86_64-cfntools)])
    assert_field(fields[2], DialogFieldTextBox,      :name => "param_cartridges", :default_value => "cron,diy,haproxy,mysql,nodejs,perl,php,postgresql,python,ruby")
  end

  def assert_parameter_group2(group)
    group.should have_attributes(
      :label   => "DB parameters",
      :display => "edit",
    )

    fields = group.dialog_fields
    fields.size.should == 3

    assert_field(fields[0], DialogFieldTextBox,     :name => "param_admin_pass", :validator_rule => '[a-zA-Z0-9]+')
    assert_field(fields[1], DialogFieldTextBox,     :name => "param_db_port",    :label => 'Port Number')
    assert_field(fields[2], DialogFieldTextAreaBox, :name => "param_metadata")
  end
end
