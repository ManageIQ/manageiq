class ServiceTemplateOrchestration < ServiceTemplate
  include ServiceOrchestrationMixin

  def service_class_type
    "ServiceOrchestration"
  end

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end
end
