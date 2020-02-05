class Dialog
  class AnsibleTowerJobTemplateDialogService
    def self.create_dialog(template, label = nil)
      template, label = label, template if template.kind_of?(String)
      new.create_dialog(template, label)
    end

    def create_dialog(template, label = nil)
      label ||= template.name
      Dialog.new(:label => label, :buttons => "submit,cancel").tap do |dialog|
        tab = dialog.dialog_tabs.build(:display => "edit", :label => "Basic Information", :position => 0)

        group_pos = 0
        add_options_group(tab, group_pos, template)

        if template.survey_spec.present?
          group_pos += 1
          add_survey_group(tab, group_pos, template)
        end

        if template.variables.present?
          group_pos += 1
          add_variables_group(tab, group_pos, template)
        end

        dialog.save!
      end
    end

    private

    def add_options_group(tab, position, template)
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Options",
        :position => position
      ).tap do |dialog_group|
        add_service_name_field(dialog_group, 0)
        add_limit_field(dialog_group, 1) if template.supports_limit?
      end
    end

    def add_options_field(group, position, options)
      group.dialog_fields.build(
        :type           => "DialogFieldTextBox",
        :name           => options[:name],
        :description    => options[:description],
        :data_type      => "string",
        :display        => "edit",
        :required       => false,
        :dynamic        => false,
        :options        => {:protected => false},
        :label          => options[:label],
        :position       => position,
        :reconfigurable => false,
        :dialog_group   => group,
        :read_only      => false
      )
    end

    def add_service_name_field(group, position)
      options = {
        :name        => "service_name",
        :description => "Name of the new service",
        :label       => "Service Name",
      }
      add_options_field(group, position, options)
    end

    def add_limit_field(group, position)
      options = {
        :name        => "limit",
        :description => "A ':'-separated string to constrain the list of hosts managed or affected by the playbook",
        :label       => "Limit",
      }
      add_options_field(group, position, options)
    end

    def add_survey_group(tab, position, template)
      parameters = template.survey_spec['spec'] || []
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Survey",
        :position => position
      ).tap do |dialog_group|
        parameters.each_with_index { |param, index| add_parameter_field(param, dialog_group, index) }
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
      default_value = if parameter['type'] == 'multiselect'
                        parameter['default'].try(:split, "\n")
                      else # 'multiplechoice'
                        parameter['default'].try(:split, "\n").try(:first)
                      end
      group.dialog_fields.build(
        :type           => "DialogFieldDropDownList",
        :name           => "param_#{parameter['variable']}",
        :display        => "edit",
        :required       => parameter['required'],
        :dynamic        => false,
        :options        => {:force_multi_value => parameter["type"] == "multiselect"},
        :values         => dropdown_list,
        :default_value  => default_value || dropdown_list.first,
        :label          => parameter['question_name'],
        :description    => parameter['question_description'],
        :reconfigurable => false,
        :data_type      => "string",
        :position       => position,
        :dialog_group   => group,
        :read_only      => false
      )
    end

    def create_parameter_textinput(parameter, group, position, type)
      group.dialog_fields.build(
        :type           => type,
        :name           => "param_#{parameter['variable']}",
        :data_type      => parameter['type'] == 'integer' ? 'integer' : 'string',
        :display        => "edit",
        :required       => parameter['required'],
        :dynamic        => false,
        :default_value  => parameter['default'],
        :options        => {:protected => parameter['type'] == 'password'},
        :label          => parameter['question_name'],
        :description    => parameter['question_description'],
        :reconfigurable => false,
        :position       => position,
        :dialog_group   => group,
        :read_only      => false
      )
    end

    def add_variables_group(tab, position, template)
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Extra Variables",
        :position => position
      ).tap do |dialog_group|
        template.variables.each_with_index do |(key, value), index|
          value = value.to_json if [Hash, Array].include?(value.class)
          add_variable_field(key, value, dialog_group, index)
        end
      end
    end

    def add_variable_field(key, value, group, position)
      group.dialog_fields.build(
        :type           => "DialogFieldTextBox",
        :name           => "param_#{key}",
        :data_type      => "string",
        :display        => "edit",
        :required       => false,
        :dynamic        => false,
        :default_value  => value,
        :label          => key,
        :description    => key,
        :reconfigurable => false,
        :position       => position,
        :dialog_group   => group,
        :read_only      => true
      )
    end
  end
end
