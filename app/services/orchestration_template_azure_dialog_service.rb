class OrchestrationTemplateAzureDialogService < OrchestrationTemplateDialogService
  private

  def add_deployment_options(dialog_group, position)
    add_resource_group_list(dialog_group, position)
    add_new_resource_group_field(dialog_group, position + 1)
    add_mode_field(dialog_group, position + 2)
  end

  def add_mode_field(group, position)
    description = "Select deployment mode.\n"\
                  "WARNING: Complete mode will delete all resources from "\
                  "the group that are not in the template."

    group.dialog_fields.build(
      :type          => "DialogFieldDropDownList",
      :name          => "deploy_mode",
      :description   => description,
      :data_type     => "string",
      :display       => "edit",
      :required      => true,
      :values        => [["Incremental", "Incremental (Default)"],
                         ["Complete",    "Complete (Delete other resources in the group)"]],
      :default_value => "Incremental",
      :options       => {:sort_by => :description, :sort_order => :ascending},
      :label         => "Mode",
      :position      => position,
      :dialog_group  => group
    )
  end

  def add_resource_group_list(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldDropDownList",
      :name         => "resource_group",
      :description  => "Select an existing resource group for deployment",
      :data_type    => "string",
      :display      => "edit",
      :dynamic      => true,
      :required     => false,
      :label        => "Existing Resource Group",
      :position     => position,
      :dialog_group => group
    ).tap do |dialog_field|
      dialog_field.resource_action.fqname = "/Cloud/Orchestration/Operations/Methods/Available_Resource_Groups"
    end
  end

  def add_new_resource_group_field(group, position)
    group.dialog_fields.build(
      :type           => "DialogFieldTextBox",
      :name           => "new_resource_group",
      :description    => "Create a new resource group upon deployment",
      :data_type      => "string",
      :display        => "edit",
      :required       => false,
      :options        => {:protected => false},
      :validator_type => 'regex',
      :validator_rule => '^[A-Za-z][A-Za-z0-9\-_]*$',
      :label          => "(or) New Resource Group",
      :position       => position,
      :dialog_group   => group
    )
  end
end
