module MiqAeMethodService
  class MiqAeServiceVmMigrateRequest < MiqAeServiceMiqRequest
    def ci_type
      'vm'
    end
  end
end
