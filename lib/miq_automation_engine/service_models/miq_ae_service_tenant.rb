module MiqAeMethodService
  class MiqAeServiceTenant < MiqAeServiceModelBase
    expose :tenant_quotas,  :association => true
  end
end
