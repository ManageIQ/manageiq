class ManageIQ::Providers::AnsibleTower::InventoryCollectionDefault::AutomationManager < ManagerRefresh::InventoryCollectionDefault
  class << self
    def inventory_root_groups(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::AutomationManager::InventoryRootGroup,
        :association => :inventory_root_groups,
      }
      attributes.merge!(extra_attributes)
    end

    def configured_systems(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem,
        :association => :configured_systems,
        :manager_ref => [:manager_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def configuration_scripts(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript,
        :association => :configuration_scripts,
        :manager_ref => [:manager_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def configuration_script_sources(extra_attributes = {})
      attributes = {
        :model_class => ConfigurationScriptSource,
        :association => :configuration_script_sources,
        :manager_ref => [:manager_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def configuration_script_payloads(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook,
        :association => :configuration_script_payloads,
        :manager_ref => [:configuration_script_source, :manager_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def credentials(extra_attributes = {})
      attributes = {
        :model_class => ManageIQ::Providers::AutomationManager::Authentication,
        :association => :credentials,
        :manager_ref => [:manager_ref],
      }
      attributes.merge!(extra_attributes)
    end
  end
end
