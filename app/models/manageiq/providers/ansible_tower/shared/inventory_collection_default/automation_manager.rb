module ManageIQ::Providers::AnsibleTower::Shared::InventoryCollectionDefault::AutomationManager
  extend ActiveSupport::Concern

  module ClassMethods
    def provider_module
      ManageIQ::Providers::Inflector.provider_module(self)
    end

    def inventory_root_groups(extra_attributes = {})
      attributes = {
        :model_class => self.provider_module::AutomationManager::InventoryRootGroup,
        :association => :inventory_root_groups,
      }
      attributes.merge!(extra_attributes)
    end

    def configured_systems(extra_attributes = {})
      attributes = {
        :model_class => self.provider_module::AutomationManager::ConfiguredSystem,
        :association => :configured_systems,
        :manager_ref => [:manager_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def configuration_scripts(extra_attributes = {})
      attributes = {
        :model_class => self.provider_module::AutomationManager::ConfigurationScript,
        :association => :configuration_scripts,
        :manager_ref => [:manager_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def configuration_script_sources(extra_attributes = {})
      attributes = {
        :model_class => self.provider_module::AutomationManager::ConfigurationScriptSource,
        :association => :configuration_script_sources,
        :manager_ref => [:manager_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def configuration_script_payloads(extra_attributes = {})
      attributes = {
        :model_class => self.provider_module::AutomationManager::Playbook,
        :association => :configuration_script_payloads,
        :manager_ref => [:configuration_script_source, :manager_ref],
      }
      attributes.merge!(extra_attributes)
    end

    def credentials(extra_attributes = {})
      attributes = {
        :model_class => self.provider_module::AutomationManager::Credential,
        :association => :credentials,
        :manager_ref => [:manager_ref],
      }
      attributes.merge!(extra_attributes)
    end
  end
end
