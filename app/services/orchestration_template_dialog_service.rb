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

      if template.kind_of?(OrchestrationTemplateAzure)
        add_azure_stack_options(dialog_group, 2)
      else
        add_aws_openstack_stack_options(dialog_group, 2)
      end
    end
  end

  def add_aws_openstack_stack_options(dialog_group, position)
    add_on_failure_field(dialog_group, position)
    add_timeout_field(dialog_group, position + 1)
  end

  def add_azure_stack_options(dialog_group, position)
    add_resource_group_field(dialog_group, position)
    add_mode_field(dialog_group, position + 1)
  end

  def add_parameter_group(parameter_group, tab, position)
    tab.dialog_groups.build(
      :display  => "edit",
      :label    => parameter_group.label,
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

  def add_on_failure_field(group, position)
    group.dialog_fields.build(
      :type          => "DialogFieldDropDownList",
      :name          => "stack_onfailure",
      :description   => "Select what to do if stack creation failed",
      :data_type     => "string",
      :display       => "edit",
      :required      => true,

      # %w(DELETE Delete\ stack) is available with aws-sdk v2
      :values        => [%w(ROLLBACK Rollback), %w(DO_NOTHING Do\ nothing)],
      :default_value => "ROLLBACK",
      :options       => {:sort_by => :description, :sort_order => :ascending},
      :label         => "On Failure",
      :position      => position,
      :dialog_group  => group
    )
  end

  def add_timeout_field(group, position)
    group.dialog_fields.build(
      :type           => "DialogFieldTextBox",
      :name           => "stack_timeout",
      :description    => "Abort the creation if it does not complete in a proper time window",
      :data_type      => "integer",
      :display        => "edit",
      :required       => false,
      :options        => {:protected => false},
      :label          => "Timeout(minutes, optional)",
      :position       => position,
      :dialog_group   => group
    )
  end

  def add_mode_field(group, position)
    group.dialog_fields.build(
      :type          => "DialogFieldDropDownList",
      :name          => "deploy_mode",
      :description   => "Select deployment mode",
      :data_type     => "string",
      :display       => "edit",
      :required      => true,
      :values        => [%w(Incremental Incremental), %w(Complete Complete)],
      :default_value => "Incremental",
      :options       => {:sort_by => :description, :sort_order => :ascending},
      :label         => "Mode",
      :position      => position,
      :dialog_group  => group
    )
  end

  def add_resource_group_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldDropDownList",
      :name         => "resource_group",
      :description  => "Resource group to which stack is to deploy",
      :data_type    => "string",
      :display      => "edit",
      :dynamic      => true,
      :required     => false,
      :label        => "Resource Group",
      :position     => position,
      :dialog_group => group
    ).tap do |dialog_field|
      dialog_field.resource_action.fqname = "/Cloud/Orchestration/Operations/Methods/Available_Resource_Groups"
    end
  end

  def add_parameter_field(parameter, group, position)
    if parameter.constraints
      dropdown = parameter.constraints.detect { |c| c.kind_of? OrchestrationTemplate::OrchestrationParameterAllowed }
    end
    if dropdown
      create_parameter_dropdown_list(parameter, group, position, dropdown)
    else
      create_parameter_textbox(parameter, group, position)
    end
  end

  def create_parameter_dropdown_list(parameter, group, position, dropdown)
    dropdown_list = dropdown.allowed_values.collect { |v| [v, v] }
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
end
