module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_AnsibleTower_ConfigurationManager < MiqAeServiceManageIQ_Providers_ConfigurationManager
    expose :configuration_scripts, :association => true
  end
end
