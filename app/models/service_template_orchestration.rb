class ServiceTemplateOrchestration < ServiceTemplate
  include ServiceOrchestrationMixin

  before_save :remove_invalid_resource

  def remove_invalid_resource
    # remove the resource from both memory and table
    service_resources.to_a.delete_if { |r| r.destroy unless r.resource }
  end

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end

  def self.default_provisioning_entry_point
    '/Cloud/Orchestration/Provisioning/StateMachines/Provision/default'
  end

  def self.default_reconfiguration_entry_point
    '/Cloud/Orchestration/Reconfiguration/StateMachines/Reconfigure/default'
  end

  def my_zone
    orchestration_manager.try(:my_zone) || MiqServer.my_zone
  end
end
