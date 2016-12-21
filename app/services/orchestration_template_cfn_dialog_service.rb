class OrchestrationTemplateCfnDialogService < OrchestrationTemplateDialogService
  private

  def add_deployment_options(dialog_group, position)
    add_on_failure_field(dialog_group, position)
    add_timeout_field(dialog_group, position + 1)
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
      :type         => "DialogFieldTextBox",
      :name         => "stack_timeout",
      :description  => "Abort the creation if it does not complete in a proper time window",
      :data_type    => "integer",
      :display      => "edit",
      :required     => false,
      :options      => {:protected => false},
      :label        => "Timeout(minutes, optional)",
      :position     => position,
      :dialog_group => group
    )
  end
end
