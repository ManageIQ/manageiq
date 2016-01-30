module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Azure_CloudManager < MiqAeServiceManageIQ_Providers_CloudManager
    expose :resource_groups, :association => true
  end
end
