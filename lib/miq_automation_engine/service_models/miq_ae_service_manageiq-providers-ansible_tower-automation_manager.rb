module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_AnsibleTower_AutomationManager <
      MiqAeServiceManageIQ_Providers_ExternalAutomationManager
    expose :configuration_scripts, :association => true
    expose :credentials, :association => true
  end
end
