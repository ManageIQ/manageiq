class Dialog
  class OrchestrationTemplateServiceDialog
    def self.create_dialog(name, template)
      new.create_dialog(name, template)
    end

    def create_dialog(name, template)
      Dialog.new(:name => name, :buttons => "submit,cancel").tap do |dialog|
        template.tabs.each_with_index do |data, idx|
          tab    = dialog.dialog_tabs.build(:display => "edit", :label => data[:title], :position => idx)
          offset = data[:stack_group] ? 1 : 0
          add_stack_group(data[:stack_group], tab, 0) if data[:stack_group]
          Array(data[:param_groups]).each_with_index { |group, i| add_parameter_group(group, tab, i + offset) }
        end
        dialog.save!
      end
    end

    private

    def add_stack_group(deploy_options, tab, position)
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Options",
        :position => position
      ).tap do |dialog_group|
        deploy_options.each_with_index { |opt, index| add_field(opt, dialog_group, index) }
      end
    end

    def add_parameter_group(parameter_group, tab, position)
      return if parameter_group.parameters.blank?

      tab.dialog_groups.build(
        :display  => "edit",
        :label    => parameter_group.label || "Parameter Group#{position}",
        :position => position
      ).tap do |dialog_group|
        parameter_group.parameters.each_with_index { |param, index| add_field(param, dialog_group, index, 'param_') }
      end
    end

    def add_field(parameter, group, position, name_prefix = nil)
      if parameter.constraints
        dynamic_dropdown = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterAllowedDynamic) }
        return create_dynamic_dropdown_list(parameter, group, position, dynamic_dropdown, name_prefix) if dynamic_dropdown

        dropdown = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterAllowed) }
        return create_dropdown_list(parameter, group, position, dropdown, name_prefix) if dropdown

        checkbox = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterBoolean) }
        return create_checkbox(parameter, group, position, name_prefix) if checkbox

        textarea = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterMultiline) }
        return create_textarea(parameter, group, position, name_prefix) if textarea
      end

      create_textbox(parameter, group, position, name_prefix)
    end

    def create_dynamic_dropdown_list(parameter, group, position, dynamic_dropdown, name_prefix)
      group.dialog_fields.build(
        :type         => "DialogFieldDropDownList",
        :name         => "#{name_prefix}#{parameter.name}",
        :data_type    => "string",
        :dynamic      => true,
        :display      => "edit",
        :required     => parameter.required,
        :label        => parameter.label,
        :description  => parameter.description,
        :position     => position,
        :dialog_group => group
      ).tap do |dialog_field|
        dialog_field.resource_action.fqname = dynamic_dropdown.fqname
      end
    end

    def create_dropdown_list(parameter, group, position, dropdown, name_prefix)
      values = dropdown.allowed_values
      dropdown_list = values.kind_of?(Hash) ? values.to_a : values.collect { |v| [v, v] }
      group.dialog_fields.build(
        :type              => "DialogFieldDropDownList",
        :name              => "#{name_prefix}#{parameter.name}",
        :data_type         => "string",
        :display           => "edit",
        :force_multi_value => dropdown.allow_multiple,
        :required          => parameter.required,
        :values            => dropdown_list,
        :default_value     => parameter.default_value || dropdown_list.first,
        :label             => parameter.label,
        :description       => parameter.description,
        :reconfigurable    => parameter.reconfigurable,
        :position          => position,
        :dialog_group      => group
      )
    end

    def create_textbox(parameter, group, position, name_prefix)
      data_type = parameter.data_type.casecmp('integer').zero? ? 'integer' : 'string'
      if parameter.constraints
        pattern = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterPattern) }
      end
      group.dialog_fields.build(
        :type           => 'DialogFieldTextBox',
        :name           => "#{name_prefix}#{parameter.name}",
        :data_type      => data_type,
        :display        => "edit",
        :required       => parameter.required,
        :default_value  => parameter.default_value,
        :options        => {:protected => parameter.hidden?},
        :validator_type => pattern ? 'regex' : nil,
        :validator_rule => pattern.try(:pattern),
        :label          => parameter.label,
        :description    => parameter.description,
        :reconfigurable => parameter.reconfigurable,
        :position       => position,
        :dialog_group   => group
      )
    end

    def create_textarea(parameter, group, position, name_prefix)
      group.dialog_fields.build(
        :type           => 'DialogFieldTextAreaBox',
        :name           => "#{name_prefix}#{parameter.name}",
        :data_type      => 'string',
        :display        => "edit",
        :required       => parameter.required,
        :default_value  => parameter.default_value,
        :label          => parameter.label,
        :description    => parameter.description,
        :reconfigurable => parameter.reconfigurable,
        :position       => position,
        :dialog_group   => group
      )
    end

    def create_checkbox(parameter, group, position, name_prefix)
      group.dialog_fields.build(
        :type           => "DialogFieldCheckBox",
        :name           => "#{name_prefix}#{parameter.name}",
        :data_type      => "boolean",
        :display        => "edit",
        :default_value  => parameter.default_value,
        :label          => parameter.label,
        :description    => parameter.description,
        :reconfigurable => parameter.reconfigurable,
        :position       => position,
        :dialog_group   => group
      )
    end
  end
end
