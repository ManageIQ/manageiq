class ServiceTemplateOrchestration < ServiceTemplate
  include ServiceOrchestrationMixin

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end
end
