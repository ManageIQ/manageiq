module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_EmbeddedAnsible_AutomationManager_Job < MiqAeServiceManageIQ_Providers_EmbeddedAutomationManager_OrchestrationStack
    expose :manager, :association => true
    undef retire_now
  end
end
