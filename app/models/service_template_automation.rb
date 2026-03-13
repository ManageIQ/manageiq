class ServiceTemplateAutomation < ServiceTemplate
  include ServiceTemplateAutomationMixin

  def create_subtasks(_parent_service_task, _parent_service)
    if generic?
      # no sub task is needed for this service
      []
    else
      super
    end
  end

  def generic?
    prov_type.start_with?("generic_")
  end
end
