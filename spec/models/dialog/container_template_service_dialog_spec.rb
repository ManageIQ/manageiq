RSpec.describe Dialog::ContainerTemplateServiceDialog do
  describe "#create_dialog" do
    let(:container_template) { FactoryBot.create(:container_template) }
    let(:params) { [] }
    before do
      params << FactoryBot.create(:container_template_parameter, :name => "name_1", :value => "value_1", :required => true)
      params << FactoryBot.create(:container_template_parameter, :name => "name_2", :value => "value_2")
      params << FactoryBot.create(:container_template_parameter, :name => "name_3", :value => "value_3", :required => true, :generate => "expression")
    end

    it "creates a dialog for a container template with parameters" do
      container_template.container_template_parameters = params

      dialog = described_class.create_dialog("mydialog1", container_template.container_template_parameters)
      expect(dialog).to have_attributes(:label => 'mydialog1', :buttons => "submit,cancel")

      tabs = dialog.dialog_tabs
      expect(tabs.size).to eq(1)
      assert_main_tab(tabs[0])
    end

    it "raises an error for a container template with no parameters" do
      expect { described_class.create_dialog("mydialog2", container_template.container_template_parameters) }
        .to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  def assert_main_tab(tab)
    assert_tab_attributes(tab)

    groups = tab.dialog_groups
    expect(groups.size).to eq(2)

    assert_options_group(groups[0])
    assert_parameters_group(groups[1])
  end

  def assert_tab_attributes(tab)
    expect(tab).to have_attributes(:label => "Basic Information", :display => "edit")
  end

  def assert_options_group(group)
    expect(group).to have_attributes(:label => "Options", :display => "edit")
    fields = group.dialog_fields
    expect(fields.size).to eq(2)
    assert_field(fields[0], DialogFieldDropDownList, :label => "Add To Existing Project", :name => "existing_project_name", :dynamic => true)
    assert_field(fields[1], DialogFieldTextBox, :label => "(or) Add To New Project", :name => "new_project_name", :data_type => 'string')
  end

  def assert_field(field, clss, attributes)
    expect(field).to be_kind_of clss
    expect(field).to have_attributes(attributes)
  end

  def assert_parameters_group(group)
    expect(group).to have_attributes(:label => "Parameters", :display => "edit")

    fields = group.dialog_fields
    expect(fields.size).to eq(3)

    assert_field(fields[0], DialogFieldTextBox, :name => "param_#{params[0].name}", :default_value => params[0].value, :data_type => 'string', :required => true)
    assert_field(fields[1], DialogFieldTextBox, :name => "param_#{params[1].name}", :default_value => params[1].value, :data_type => 'string', :required => nil)
    assert_field(fields[2], DialogFieldTextBox, :name => "param_#{params[2].name}", :default_value => params[2].value, :data_type => 'string', :required => false)
  end
end
