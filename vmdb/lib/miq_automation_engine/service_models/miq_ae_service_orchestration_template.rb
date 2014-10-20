module MiqAeMethodService
  class MiqAeServiceOrchestrationTemplate < MiqAeServiceModelBase
    def deploy(provider_id, stack_name, options)
      object_send(:deploy, provider_id, stack_name, options)
    end
  end
end
