class OrchestrationTemplateCfnDialogService < OrchestrationTemplateDialogService
  private

  def add_deployment_options(dialog_group, position)
    add_on_failure_field(dialog_group, position)
    add_timeout_field(dialog_group, position + 1)
    add_notifications_field(dialog_group, position + 2)
    add_capabilities_field(dialog_group, position + 3)
    add_resource_types_field(dialog_group, position + 4)
    add_role_field(dialog_group, position + 5)
    add_tags_field(dialog_group, position + 6)
    add_policy_field(dialog_group, position + 7)
  end

  def add_on_failure_field(group, position)
    group.dialog_fields.build(
      :type          => "DialogFieldDropDownList",
      :name          => "stack_onfailure",
      :description   => "Select what to do if stack creation failed",
      :data_type     => "string",
      :display       => "edit",
      :required      => true,
      :values        => [%w(ROLLBACK Rollback), %w(DO_NOTHING Do\ nothing), %w(DELETE Delete\ stack)],
      :default_value => "ROLLBACK",
      :options       => {:sort_by => :description, :sort_order => :ascending},
      :label         => "On Failure",
      :position      => position,
      :dialog_group  => group
    )
  end

  def add_timeout_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldTextBox",
      :name         => "stack_timeout",
      :description  => "Abort the creation if it does not complete in a proper time window",
      :data_type    => "integer",
      :display      => "edit",
      :required     => false,
      :options      => {:protected => false},
      :label        => "Timeout(minutes)",
      :position     => position,
      :dialog_group => group
    )
  end

  def add_notifications_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldTextAreaBox",
      :name         => "stack_notifications",
      :description  => "Notification SNS topic ARNs, one ARN per line",
      :data_type    => "string",
      :display      => "edit",
      :required     => false,
      :options      => {:protected => false},
      :label        => "Notification ARNs",
      :position     => position,
      :dialog_group => group
    )
  end

  def add_capabilities_field(group, position)
    group.dialog_fields.build(
      :type          => "DialogFieldDropDownList",
      :name          => "stack_capabilities",
      :description   => "Choose one or both capabilities",
      :data_type     => "string",
      :display       => "edit",
      :required      => false,
      :values        => [['', '<default>'], %w(CAPABILITY_IAM CAPABILITY_IAM), %w(CAPABILITY_NAMED_IAM CAPABILITY_NAMED_IAM)],
      :default_value => "",
      :options       => {:sort_by => :description, :sort_order => :ascending},
      :label         => "Capabilities",
      :position      => position,
      :dialog_group  => group
    )
  end

  def add_resource_types_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldTextAreaBox",
      :name         => "stack_resource_types",
      :description  => "Grand permissions to selected types, one type per line",
      :data_type    => "string",
      :display      => "edit",
      :required     => false,
      :options      => {:protected => false},
      :label        => "Permitted resource types",
      :position     => position,
      :dialog_group => group
    )
  end

  def add_role_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldTextBox",
      :name         => "stack_role",
      :description  => "ARN of an IAM role used to create the stack",
      :data_type    => "string",
      :display      => "edit",
      :required     => false,
      :options      => {:protected => false},
      :label        => "Role ARN",
      :position     => position,
      :dialog_group => group
    )
  end

  def add_tags_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldTextAreaBox",
      :name         => "stack_tags",
      :description  => "Key-value pairs with format key1=>val1, one pair per line",
      :data_type    => "string",
      :display      => "edit",
      :required     => false,
      :options      => {:protected => false},
      :label        => "AWS Tags",
      :position     => position,
      :dialog_group => group
    )
  end

  def add_policy_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldTextAreaBox",
      :name         => "stack_policy",
      :description  => "URL of an policy file or the actual content of the policy",
      :data_type    => "string",
      :display      => "edit",
      :required     => false,
      :options      => {:protected => false},
      :label        => "Policy",
      :position     => position,
      :dialog_group => group
    )
  end
end
