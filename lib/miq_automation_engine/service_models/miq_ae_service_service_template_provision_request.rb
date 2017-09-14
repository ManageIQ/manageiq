module MiqAeMethodService
  class MiqAeServiceServiceTemplateProvisionRequest < MiqAeServiceMiqRequest
    require_relative "mixins/miq_ae_service_miq_provision_mixin"
    include MiqAeServiceMiqProvisionMixin

    def ci_type
      'service'
    end
  end
end
