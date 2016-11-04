class ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplateDialogService < ::OrchestrationTemplateDialogService
  private

  def add_deployment_options(group, position)
    add_availability_zone_field(group, position)
  end

  def add_availability_zone_field(group, position)
    group.dialog_fields.build(
      :type         => "DialogFieldDropDownList",
      :name         => "availability_zone",
      :description  => "Availability zone where the stack will be deployed",
      :data_type    => "string",
      :dynamic      => true,
      :display      => "edit",
      :required     => true,
      :label        => "Availability zone",
      :position     => position,
      :dialog_group => group
    ).tap do |dialog_field|
      dialog_field.resource_action.fqname = "/Cloud/Orchestration/Operations/Methods/Available_Availability_Zones"
    end
  end
end
