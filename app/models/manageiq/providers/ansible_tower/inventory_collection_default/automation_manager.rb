class ManageIQ::Providers::AnsibleTower::InventoryCollectionDefault::AutomationManager
  class << self
    def inventory_groups
      {
        :model_class => ManageIQ::Providers::AutomationManager::InventoryRootGroup,
        :association => :inventory_root_groups,
      }
    end

    def configured_systems
      {
        :model_class => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem,
        :association => :configured_systems,
        :manager_ref => [:manager_ref],
      }
    end

    def configuration_scripts
      {
        :model_class => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript,
        :association => :configuration_scripts,
        :manager_ref => [:manager_ref],
      }
    end

    def configuration_script_sources
      {
        :model_class => ConfigurationScriptSource,
        :association => :configuration_script_sources,
        :manager_ref => [:manager_ref],
      }
    end

    def playbooks
      {
        :model_class => ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook,
        :association => :configuration_script_payloads,
        :manager_ref => [:manager_ref],
      }
    end

    def credentials
      {
        :model_class => ManageIQ::Providers::AutomationManager::Authentication,
        :association => :credentials,
        :manager_ref => [:manager_ref],
      }
    end
  end
end
