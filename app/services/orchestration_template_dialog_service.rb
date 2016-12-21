class OrchestrationTemplateDialogService
  def create_dialog(dialog_label, template)
    Dialog.new(:label => dialog_label, :buttons => "submit,cancel").tap do |dialog|
      tab = dialog.dialog_tabs.build(:display => "edit", :label => "Basic Information", :position => 0)
      add_stack_group(tab, 0, template)

      template.parameter_groups.each_with_index do |parameter_group, index|
        add_parameter_group(parameter_group, tab, index + 1)
      end
      dialog.save!
    end
  end

  private

  def add_stack_group(tab, position, template)
    tab.dialog_groups.build(
      :display  => "edit",
      :label    => "Options",
      :position => position
    ).tap do |dialog_group|
      add_tenant_name_field(dialog_group, 0)
      add_stack_name_field(dialog_group, 1)
      add_deployment_options(dialog_group, 2)
    end
  end

  def add_parameter_group(parameter_group, tab, position)
    return if parameter_group.parameters.blank?

    tab.dialog_groups.build(
      :display  => "edit",
      :label    => parameter_group.label || "Parameter Group#{position}",
      :position => position
    ).tap do |dialog_group|
      parameter_group.parameters.each_with_index { |param, index| add_parameter_field(param, dialog_group, index) }
    end
  end

  def add_tenant_name_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldDropDownList",
      :name         => "tenant_name",
      :description  => "Tenant where the stack will be deployed",
      :data_type    => "string",
      :dynamic      => true,
      :display      => "edit",
      :required     => false,
      :label        => "Tenant",
      :position     => position,
      :dialog_group => group
    ).tap do |dialog_field|
      dialog_field.resource_action.fqname = "/Cloud/Orchestration/Operations/Methods/Available_Tenants"
    end
  end

  def add_stack_name_field(group, position)
    group.dialog_fields.build(
      :type           => "DialogFieldTextBox",
      :name           => "stack_name",
      :description    => "Name of the stack",
      :data_type      => "string",
      :display        => "edit",
      :required       => true,
      :options        => {:protected => false},
      :validator_type => 'regex',
      :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$',
      :label          => "Stack Name",
      :position       => position,
      :dialog_group   => group
    )
  end

  def add_parameter_field(parameter, group, position)
    if parameter.constraints
      dynamic_dropdown = parameter.constraints.detect { |c| c.kind_of? OrchestrationTemplate::OrchestrationParameterAllowedDynamic }
      return create_parameter_dynamic_dropdown_list(parameter, group, position, dynamic_dropdown) if dynamic_dropdown

      dropdown = parameter.constraints.detect { |c| c.kind_of? OrchestrationTemplate::OrchestrationParameterAllowed }
      return create_parameter_dropdown_list(parameter, group, position, dropdown) if dropdown

      checkbox = parameter.constraints.detect { |c| c.kind_of? OrchestrationTemplate::OrchestrationParameterBoolean }
      return create_parameter_checkbox(parameter, group, position) if checkbox
    end

    create_parameter_textbox(parameter, group, position)
  end

  def create_parameter_dynamic_dropdown_list(parameter, group, position, dynamic_dropdown)
    group.dialog_fields.build(
      :type         => "DialogFieldDropDownList",
      :name         => "param_#{parameter.name}",
      :data_type    => "string",
      :dynamic      => true,
      :display      => "edit",
      :required     => false,
      :label        => parameter.label,
      :description  => parameter.description,
      :position     => position,
      :dialog_group => group
    ).tap do |dialog_field|
      dialog_field.resource_action.fqname = dynamic_dropdown.fqname
    end
  end

  def create_parameter_dropdown_list(parameter, group, position, dropdown)
    values = dropdown.allowed_values
    dropdown_list = values.kind_of?(Hash) ? values.to_a : values.collect { |v| [v, v] } 
    group.dialog_fields.build(
      :type           => "DialogFieldDropDownList",
      :name           => "param_#{parameter.name}",
      :data_type      => "string",
      :display        => "edit",
      :required       => true,
      :values         => dropdown_list,
      :default_value  => parameter.default_value || dropdown_list.first,
      :label          => parameter.label,
      :description    => parameter.description,
      :reconfigurable => true,
      :position       => position,
      :dialog_group   => group
    )
  end

  def create_parameter_textbox(parameter, group, position)
    field_type = parameter.data_type == 'json' ? "DialogFieldTextAreaBox" : "DialogFieldTextBox"
    if parameter.constraints
      pattern = parameter.constraints.detect { |c| c.kind_of? OrchestrationTemplate::OrchestrationParameterPattern }
    end
    group.dialog_fields.build(
      :type           => field_type,
      :name           => "param_#{parameter.name}",
      :data_type      => "string",
      :display        => "edit",
      :required       => true,
      :default_value  => parameter.default_value,
      :options        => {:protected => parameter.hidden?},
      :validator_type => pattern ? 'regex' : nil,
      :validator_rule => pattern.try(:pattern),
      :label          => parameter.label,
      :description    => parameter.description,
      :reconfigurable => true,
      :position       => position,
      :dialog_group   => group
    )
  end

  def create_parameter_checkbox(parameter, group, position)
    group.dialog_fields.build(
      :type           => "DialogFieldCheckBox",
      :name           => "param_#{parameter.name}",
      :data_type      => "boolean",
      :display        => "edit",
      :default_value  => parameter.default_value,
      :options        => {:protected => parameter.hidden?},
      :label          => parameter.label,
      :description    => parameter.description,
      :reconfigurable => true,
      :position       => position,
      :dialog_group   => group
    )
  end

  def add_deployment_options(_group, _position)
    # default do nothing; can be overridden by each provider
  end
end
