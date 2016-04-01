class AnsibleTowerJobTemplateDialogService
  def create_dialog(template, label = nil)
    label ||= template.name
    Dialog.new(:label => label, :buttons => "submit,cancel").tap do |dialog|
      tab = dialog.dialog_tabs.build(:display => "edit", :label => "Basic Information", :position => 0)

      group_pos = 0
      add_options_group(tab, group_pos)

      unless template.survey_spec.blank?
        group_pos += 1
        add_survey_group(tab, group_pos, template)
      end

      unless template.variables.blank?
        group_pos += 1
        add_variables_group(tab, group_pos, template)
      end

      dialog.save!
    end
  end

  private

  def add_options_group(tab, position)
    tab.dialog_groups.build(
      :display  => "edit",
      :label    => "Options",
      :position => position
    ).tap do |dialog_group|
      add_limit_field(dialog_group, 0)
    end
  end

  def add_limit_field(group, position)
    group.dialog_fields.build(
      :type           => "DialogFieldTextBox",
      :name           => "limit",
      :description    => "A ':'-separated string to constrain the list of hosts managed or affected by the playbook",
      :data_type      => "string",
      :display        => "edit",
      :required       => false,
      :options        => {:protected => false},
      :label          => "Limit",
      :position       => position,
      :reconfigurable => true,
      :dialog_group   => group
    )
  end

  def add_survey_group(tab, position, template)
    tab.dialog_groups.build(
      :display  => "edit",
      :label    => "Survey",
      :position => position
    ).tap do |dialog_group|
      template.survey_spec.each_with_index { |param, index| add_parameter_field(param, dialog_group, index) }
    end
  end

  def add_parameter_field(parameter, group, position)
    if parameter['type'] == 'multiselect' || parameter['type'] == 'multiplechoice'
      create_parameter_dropdown_list(parameter, group, position)
    else
      type = parameter['type'] == 'textarea' ? 'DialogFieldTextAreaBox' : 'DialogFieldTextBox'
      create_parameter_textinput(parameter, group, position, type)
    end
  end

  def create_parameter_dropdown_list(parameter, group, position)
    dropdown_list = parameter['choices'].split("\n").collect { |v| [v, v] }
    # currently we do not support multi-selected dropdown, has to take only the first default value
    default_value = parameter['default'].try(:split, "\n").try(:first)
    group.dialog_fields.build(
      :type           => "DialogFieldDropDownList",
      :name           => "param_#{parameter['variable']}",
      :display        => "edit",
      :required       => parameter['required'],
      :values         => dropdown_list,
      :default_value  => default_value || dropdown_list.first,
      :label          => parameter['question_name'],
      :description    => parameter['question_description'],
      :reconfigurable => true,
      :position       => position,
      :dialog_group   => group
    )
  end

  def create_parameter_textinput(parameter, group, position, type)
    group.dialog_fields.build(
      :type           => type,
      :name           => "param_#{parameter['variable']}",
      :data_type      => parameter['type'] == 'integer' ? 'integer' : 'string',
      :display        => "edit",
      :required       => parameter['required'],
      :default_value  => parameter['default'],
      :options        => {:protected => parameter['type'] == 'password'},
      :label          => parameter['question_name'],
      :description    => parameter['question_description'],
      :reconfigurable => true,
      :position       => position,
      :dialog_group   => group
    )
  end

  def add_variables_group(tab, position, template)
    tab.dialog_groups.build(
      :display  => "edit",
      :label    => "Extra Variables",
      :position => position
    ).tap do |dialog_group|
      template.variables.each_with_index { |(key, value), index| add_variable_field(key, value, dialog_group, index) }
    end
  end

  def add_variable_field(key, value, group, position)
    group.dialog_fields.build(
      :type           => "DialogFieldTextBox",
      :name           => "param_#{key}",
      :data_type      => "string",
      :display        => "edit",
      :required       => false,
      :default_value  => value,
      :label          => key,
      :description    => key,
      :reconfigurable => true,
      :position       => position,
      :dialog_group   => group,
      :read_only      => true
    )
  end
end
