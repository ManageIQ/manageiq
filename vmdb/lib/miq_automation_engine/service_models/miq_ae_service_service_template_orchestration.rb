module MiqAeMethodService
  class MiqAeServiceServiceTemplateOrchestration < MiqAeServiceServiceTemplate
    expose :deploy_orchestration_stack
    expose :orchestration_stack_status
    expose :convert_dialog_options
    expose :stack_name
  end
end
