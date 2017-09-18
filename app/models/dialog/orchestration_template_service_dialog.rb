class Dialog
  class OrchestrationTemplateServiceDialog
    def self.create_dialog(label, template)
      Dialog::OrchestrationTemplateServiceDialog.new.create_dialog(label, template)
    end

    def create_dialog(label, template)
      Dialog.new(:label => label, :buttons => "submit,cancel").tap do |dialog|
        tab = dialog.dialog_tabs.build(:display => "edit", :label => "Basic Information", :position => 0)
        add_stack_group(template.deployment_options, tab, 0)

        template.parameter_groups.each_with_index do |parameter_group, index|
          add_parameter_group(parameter_group, tab, index + 1)
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

    def add_field(parameter, group, position, prefix = nil)
      if parameter.constraints
        dynamic_dropdown = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterAllowedDynamic) }
        return create_dynamic_dropdown_list(parameter, group, position, dynamic_dropdown, prefix) if dynamic_dropdown

        dropdown = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterAllowed) }
        return create_dropdown_list(parameter, group, position, dropdown, prefix) if dropdown

        checkbox = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterBoolean) }
        return create_checkbox(parameter, group, position, prefix) if checkbox
      end

      create_textbox(parameter, group, position, prefix)
    end

    def create_dynamic_dropdown_list(parameter, group, position, dynamic_dropdown, prefix)
      group.dialog_fields.build(
        :type         => "DialogFieldDropDownList",
        :name         => "#{prefix}#{parameter.name}",
        :data_type    => parameter.data_type || "string",
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

    def create_dropdown_list(parameter, group, position, dropdown, prefix)
      values = dropdown.allowed_values
      dropdown_list = values.kind_of?(Hash) ? values.to_a : values.collect { |v| [v, v] }
      group.dialog_fields.build(
        :type           => "DialogFieldDropDownList",
        :name           => "#{prefix}#{parameter.name}",
        :data_type      => parameter.data_type || "string",
        :display        => "edit",
        :required       => parameter.required,
        :values         => dropdown_list,
        :default_value  => parameter.default_value || dropdown_list.first,
        :label          => parameter.label,
        :description    => parameter.description,
        :reconfigurable => parameter.reconfigurable,
        :position       => position,
        :dialog_group   => group
      )
    end

    def create_textbox(parameter, group, position, prefix)
      if parameter.data_type == 'string' || parameter.data_type == 'integer'
        data_type = parameter.data_type
        field_type = 'DialogFieldTextBox'
      else
        data_type = 'string'
        field_type = 'DialogFieldTextAreaBox'
      end
      if parameter.constraints
        pattern = parameter.constraints.detect { |c| c.kind_of?(OrchestrationTemplate::OrchestrationParameterPattern) }
      end
      group.dialog_fields.build(
        :type           => field_type,
        :name           => "#{prefix}#{parameter.name}",
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

    def create_checkbox(parameter, group, position, prefix)
      group.dialog_fields.build(
        :type           => "DialogFieldCheckBox",
        :name           => "#{prefix}#{parameter.name}",
        :data_type      => "boolean",
        :display        => "edit",
        :default_value  => parameter.default_value,
        :options        => {:protected => parameter.hidden?},
        :label          => parameter.label,
        :description    => parameter.description,
        :reconfigurable => parameter.reconfigurable,
        :position       => position,
        :dialog_group   => group
      )
    end
  end
end
