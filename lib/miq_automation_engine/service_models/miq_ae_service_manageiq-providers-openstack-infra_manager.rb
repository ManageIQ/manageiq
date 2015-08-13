module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Openstack_InfraManager < MiqAeServiceEmsInfra
    expose :orchestration_stacks, :association => true
  end
end
