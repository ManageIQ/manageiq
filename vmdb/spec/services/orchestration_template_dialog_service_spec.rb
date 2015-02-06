require "spec_helper"

describe OrchestrationTemplateDialogService do
  let(:dialog_service) { described_class.new }

  let(:template) do
    file = 'spec/fixtures/orchestration_templates/hot_parameters.yml'
    OrchestrationTemplateHot.new(:content => IO.read(file))
  end

  describe "#create_dialog" do
    it "creates a dialog with stack basic info and parameters" do
      dialog = dialog_service.create_dialog("test", template)

      dialog.should have_attributes(
        :label   => "test",
        :buttons => "submit,cancel"
      )

      tabs = dialog.dialog_tabs
      tabs.size.should == 1
      assert_stack_tab(tabs[0])
    end
  end

  def assert_stack_tab(tab)
    tab.should have_attributes(
      :label   => "Basic Information",
      :display => "edit"
    )

    groups = tab.dialog_groups
    groups.size.should == 3

    assert_stack_group(groups[0])
    assert_parameter_group1(groups[1])
    assert_parameter_group2(groups[2])
  end

  def assert_stack_group(group)
    group.should have_attributes(
      :label   => "Options",
      :display => "edit",
    )

    fields = group.dialog_fields
    fields.size.should == 3

    assert_field(fields[0], DialogFieldTextBox,      :name => "stack_name",      :validator_rule => '^[A-Za-z][A-Za-z0-9|-]*$')
    assert_field(fields[1], DialogFieldDropDownList, :name => "stack_onfailure", :values => [%w(DO_NOTHING Do\ nothing), %w(ROLLBACK Rollback)])
    assert_field(fields[2], DialogFieldTextBox,      :name => "stack_timeout",   :validator_rule => '^[1-9][0-9]*$')
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
    assert_field(fields[1], DialogFieldDropDownList, :name => "param_image_id",   :values => [%w(F18-i386-cfntools F18-i386-cfntools), %w(F18-x86_64-cfntools F18-x86_64-cfntools)])
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
