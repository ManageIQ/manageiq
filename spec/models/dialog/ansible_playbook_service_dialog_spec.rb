RSpec.describe Dialog::AnsiblePlaybookServiceDialog do
  describe "#create_dialog" do
    it "creates a dialog for a playbook with variables" do
      extra_vars = {
        'some_extra_var'  => {:default => 'blah'},
        'other_extra_var' => {:default => {'name' => 'some_value'}},
        'array_extra_var' => {:default => [{'name' => 'some_value'}]}
      }

      dialog = subject.create_dialog("mydialog1", extra_vars)
      expect(dialog).to have_attributes(:label => 'mydialog1', :buttons => "submit,cancel")

      tabs = dialog.dialog_tabs
      expect(tabs.size).to eq(1)
      assert_main_tab(tabs[0])
    end

    it "creates a dialog for a playbook with no variables" do
      dialog = described_class.create_dialog("mydialog2", {})
      expect(dialog.dialog_tabs[0].dialog_groups.size).to eq(1)
    end
  end

  def assert_main_tab(tab)
    assert_tab_attributes(tab)

    groups = tab.dialog_groups
    expect(groups.size).to eq(2)

    assert_option_group(groups[0])
    assert_variables_group(groups[1])
  end

  def assert_tab_attributes(tab)
    expect(tab).to have_attributes(:label => "Basic Information", :display => "edit")
  end

  def assert_option_group(group)
    expect(group).to have_attributes(:label => "Options", :display => "edit")
    fields = group.dialog_fields
    expect(fields.size).to eq(2)
    assert_field(fields[0], DialogFieldDropDownList, :label => "Machine Credential", :name => "credential", :dynamic => true, :required => false)
    assert_field(fields[1], DialogFieldTextBox, :label => "Hosts", :name => "hosts", :required => false, :data_type => 'string')
  end

  def assert_field(field, clss, attributes)
    expect(field).to be_kind_of clss
    expect(field).to have_attributes(attributes)
  end

  def assert_variables_group(group)
    expect(group).to have_attributes(:label => "Variables", :display => "edit")

    fields = group.dialog_fields
    expect(fields.size).to eq(3)

    assert_field(fields[0], DialogFieldTextBox, :name => 'param_some_extra_var', :default_value => 'blah', :data_type => 'string')
    assert_field(fields[1], DialogFieldTextBox, :name => 'param_other_extra_var', :default_value => '{"name":"some_value"}', :data_type => 'string')
    assert_field(fields[2], DialogFieldTextBox, :name => 'param_array_extra_var', :default_value => '[{"name":"some_value"}]', :data_type => 'string')
  end
end
