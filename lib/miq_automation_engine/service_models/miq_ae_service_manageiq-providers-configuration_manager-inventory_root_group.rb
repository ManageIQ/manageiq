module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_ConfigurationManager_InventoryRootGroup < MiqAeServiceManageIQ_Providers_ConfigurationManager_InventoryGroup
    expose :configuration_scripts, :association => true
  end
end
