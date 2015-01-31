module MiqAeMethodService
  class MiqAeServiceOrchestrationStack < MiqAeServiceModelBase
    expose :parameters,             :association => true
    expose :resources,              :association => true
    expose :outputs,                :association => true
    expose :vms,                    :association => true
    expose :security_groups,        :association => true
    expose :cloud_networks,         :association => true
    expose :orchestration_template, :association => true
    expose :ext_management_system,  :association => true
  end
end
