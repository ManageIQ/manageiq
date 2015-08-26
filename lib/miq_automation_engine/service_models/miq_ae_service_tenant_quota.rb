module MiqAeMethodService
  class MiqAeServiceTenantQuota < MiqAeServiceModelBase
    expose :tenant,  :association => true
    expose :name
    expose :unit
    expose :value
  end
end
