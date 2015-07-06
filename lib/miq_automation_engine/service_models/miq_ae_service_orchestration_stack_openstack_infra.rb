module MiqAeMethodService
  class MiqAeServiceOrchestrationStackOpenstackInfra < MiqAeServiceOrchestrationStack
    expose :raw_update_stack
    expose :update_ready?
  end
end
