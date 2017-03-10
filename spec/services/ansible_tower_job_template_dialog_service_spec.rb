describe AnsibleTowerJobTemplateDialogService do
  let(:template) { FactoryGirl.create(:configuration_script) }

  describe "#create_dialog" do
    it "creates a dialog from a job template" do
      survey =
        "{\"spec\":[{\"index\": 0, \"question_name\": \"Param1\", \"min\": 10, \
        \"default\": \"19\", \"max\": 100, \"question_description\": \"param 1\", \"required\": true, \"variable\": \
        \"param1\", \"choices\": \"\", \"type\": \"integer\"}, {\"index\": 1, \"question_name\": \"Param2\", \"min\": \
        2, \"default\": \"as\", \"max\": 5, \"question_description\": \"param 2\", \"required\": true, \"variable\": \
        \"param2\", \"choices\": \"\", \"type\": \"text\"}, {\"index\": 2, \"question_name\": \"Param3\", \"min\": \
        \"\", \"default\": \"no\\nhello\", \"max\": \"\", \"question_description\": \"param 3\", \"required\": false, \
        \"variable\": \"param3\", \"choices\": \"\", \"type\": \"textarea\"}, {\"index\": 3, \"question_name\": \
        \"Param4\", \"min\": \"\", \"default\": \"mypassword\", \"max\": \"\", \"question_description\": \"param 4\", \
        \"required\": true, \"variable\": \"param4\", \"choices\": \"\", \"type\": \"password\"}, {\"index\": 4, \
        \"question_name\": \"Param5\", \"min\": \"\", \"default\": \"Peach\", \"max\": \"\", \"question_description\": \
        \"param 5\", \"required\": true, \"variable\": \"param5\", \"choices\": \"Apple\\nBanana\\nPeach\", \"type\": \
        \"multiplechoice\"}, {\"index\": 5, \"question_description\": \"param 6\", \"min\": \"\", \"default\": \
        \"opt1\\n222\", \"max\": \"\", \"question_name\": \"Param6\", \"required\": true, \"variable\": \"param6\", \
        \"choices\": \"opt1\\n222\\nopt3\", \"type\": \"multiselect\"}, {\"index\": 6, \"question_name\": \"Param7\", \
        \"min\": \"\", \"default\": \"14.5\", \"max\": \"\", \"question_description\": \"param 7\", \
        \"required\": true, \"variable\": \"param7\", \"choices\": \"\", \"type\": \"float\"}],\"name\":\"\", \
        \"description\":\"\"}"
      allow(template).to receive(:survey_spec).and_return(JSON.parse(survey))

      allow(template).to receive(:variables).and_return('some_extra_var'  => 'blah',
                                                        'other_extra_var' => {'name' => 'some_value'},
                                                        'array_extra_var' => [{'name' => 'some_value'}]
                                                       )
      dialog = subject.create_dialog(template)

      expect(dialog).to have_attributes(:label => template.name, :buttons => "submit,cancel")

      tabs = dialog.dialog_tabs
      expect(tabs.size).to eq(1)
      assert_main_tab(tabs[0])
    end
  end

  def assert_main_tab(tab)
    assert_tab_attributes(tab)

    groups = tab.dialog_groups
    expect(groups.size).to eq(3)

    assert_option_group(groups[0])
    assert_survey_group(groups[1])
    assert_variables_group(groups[2])
  end

  def assert_tab_attributes(tab)
    expect(tab).to have_attributes(:label => "Basic Information", :display => "edit")
  end

  def assert_option_group(group)
    expect(group).to have_attributes(:label => "Options", :display => "edit")
    fields = group.dialog_fields
    expect(fields.size).to eq(1)
    expect(fields[0]).to have_attributes(:label => "Limit", :name => "limit", :required => false, :data_type => 'string')
  end

  def assert_field(field, clss, attributes)
    expect(field).to be_kind_of clss
    expect(field).to have_attributes(attributes)
  end

  def assert_survey_group(group)
    expect(group).to have_attributes(:label => "Survey", :display => "edit")
    fields = group.dialog_fields
    expect(fields.size).to eq(7)

    assert_field(fields[0], DialogFieldTextBox,      :name => 'param_param1', :data_type => 'integer',   :default_value => "19")
    assert_field(fields[1], DialogFieldTextBox,      :name => 'param_param2', :data_type => 'string',    :default_value => "as")
    assert_field(fields[2], DialogFieldTextAreaBox,  :name => 'param_param3', :data_type => 'string',    :default_value => "no\nhello")
    assert_field(fields[3], DialogFieldTextBox,      :name => 'param_param4', :data_type => 'string',    :default_value => "mypassword", :options => {:protected => true})
    assert_field(fields[4], DialogFieldDropDownList, :name => "param_param5", :default_value => "Peach", :values => [[nil, "<Choose>"], %w(Apple Apple), %w(Banana Banana), %w(Peach Peach)])
    assert_field(fields[5], DialogFieldDropDownList, :name => "param_param6", :default_value => "opt1",  :values => [%w(222 222), [nil, "<Choose>"], %w(opt1 opt1), %w(opt3 opt3)])
    assert_field(fields[6], DialogFieldTextBox,      :name => 'param_param7', :data_type => 'string',    :default_value => "14.5")
  end

  def assert_variables_group(group)
    expect(group).to have_attributes(:label => "Extra Variables", :display => "edit")

    fields = group.dialog_fields
    expect(fields.size).to eq(3)

    assert_field(fields[0], DialogFieldTextBox, :name => 'param_some_extra_var', :default_value => 'blah', :data_type => 'string', :read_only => true)
    assert_field(fields[1], DialogFieldTextBox, :name => 'param_other_extra_var', :default_value => '{"name":"some_value"}', :data_type => 'string', :read_only => true)
    assert_field(fields[2], DialogFieldTextBox, :name => 'param_array_extra_var', :default_value => '[{"name":"some_value"}]', :data_type => 'string', :read_only => true)
  end
end
