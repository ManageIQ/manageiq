module MiqAeMethodService
  class MiqAeServiceServiceTemplateOrchestration < MiqAeServiceServiceTemplate
    require_relative "mixins/miq_ae_service_service_orchestration_mixin"
    include MiqAeServiceServiceOrchestrationMixin
  end
end
