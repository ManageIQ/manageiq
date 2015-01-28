class ServiceTemplateOrchestration < ServiceTemplate
  def orchestration_template
    orchestration_templates.try(:at, 0)
  end

  def orchestration_template=(template)
    orchestration_templates.clear << template
  end

  def orchestration_manager
    orchestration_managers.try(:at, 0)
  end

  def orchestration_manager=(manager)
    orchestration_managers.clear << manager
  end

  def create_subtasks(_parent_service_task, _parent_service)
    # no sub task is needed for this service
    []
  end

  def convert_dialog_options(dialog_options)
    OptionConverter.get_converter(dialog_options, orchestration_manager.class.name).stack_create_options
  end

  def stack_name(dialog_options)
    OptionConverter.get_converter(dialog_options, orchestration_manager.class.name).stack_name
  end

  def deploy_orchestration_stack(stack_options)
    orchestration_manager.stack_create(orchestration_template, stack_options)
    nil  # if no exception
  rescue MiqException::MiqOrchestrationProvisionError => err
    err.message
  end

  def orchestration_stack_status(stack_name)
    orchestration_manager.stack_status(stack_name)
  rescue MiqException::MiqOrchestrationStatusError => err
    # naming convention requires status to end with "failed"
    return "check_status_failed", err.message
  end

  private

  has_many :orchestration_templates, :through => :service_resources, :source => :resource, :source_type => 'OrchestrationTemplate'
  has_many :orchestration_managers,  :through => :service_resources, :source => :resource, :source_type => 'ExtManagementSystem'
end
