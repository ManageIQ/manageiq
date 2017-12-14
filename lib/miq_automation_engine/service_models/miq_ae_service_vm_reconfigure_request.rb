module MiqAeMethodService
  class MiqAeServiceVmReconfigureRequest < MiqAeServiceMiqRequest
    require_relative "mixins/miq_ae_service_miq_provision_quota_mixin"
    include MiqAeServiceMiqProvisionQuotaMixin
    def ci_type
      'vm'
    end
  end
end
