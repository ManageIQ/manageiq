module MiqAeMethodService
  class MiqAeServiceVmMigrateRequest < MiqAeServiceMiqRequest
    require_relative "mixins/miq_ae_service_miq_provision_quota_mixin"
    include MiqAeServiceMiqProvisionQuotaMixin
    def ci_type
      'vm'
    end
  end
end
