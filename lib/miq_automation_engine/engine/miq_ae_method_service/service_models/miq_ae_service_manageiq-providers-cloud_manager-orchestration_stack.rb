module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_CloudManager_OrchestrationStack < MiqAeServiceOrchestrationStack
    expose :vms,                    :association => true
    expose :security_groups,        :association => true
    expose :cloud_networks,         :association => true
    expose :orchestration_template, :association => true
  end
end
