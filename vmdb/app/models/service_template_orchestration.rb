class ServiceTemplateOrchestration < ServiceTemplate
  include ServiceOrchestrationMixin

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end

  def self.default_provisioning_entry_point
    '/ManageIQ/Cloud/Orchestration/Provisioning/StateMachines/Provision/default'
  end
end
