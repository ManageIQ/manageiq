module ManagerRefresh::Inventory::AutomationManager
  extend ActiveSupport::Concern
  include Core

  class_methods do
    def has_automation_manager_configuration_scripts(options = {})
      has_configuration_scripts({
        :model_class    => provider_module::AutomationManager::ConfigurationScript,
        :association    => :configuration_scripts,
        :builder_params => {
          :manager => ->(persister) { persister.manager }
        },
      }.merge(options))
    end

    def has_automation_manager_configuration_script_payloads(options = {})
      has_configuration_script_payloads({
        :model_class    => provider_module::AutomationManager::ConfigurationScriptPayload,
        :association    => :configuration_script_payloads,
        :builder_params => {
          :manager => ->(persister) { persister.manager }
        },
      }.merge(options))
    end

    def has_automation_manager_configuration_script_sources(options = {})
      has_configuration_script_sources({
        :model_class    => provider_module::AutomationManager::ConfigurationScriptSource,
        :association    => :configuration_script_sources,
        :builder_params => {
          :manager => ->(persister) { persister.manager }
        },
      }.merge(options))
    end

    def has_automation_manager_configured_systems(options = {})
      has_configured_systems({
        :model_class    => provider_module::AutomationManager::ConfiguredSystem,
        :association    => :configured_systems,
        :builder_params => {
          :manager => ->(persister) { persister.manager }
        },
      }.merge(options))
    end

    def has_automation_manager_credentials(options = {})
      has_authentications({
        :model_class    => provider_module::AutomationManager::Credential,
        :association    => :credentials,
        :builder_params => {
          :resource => ->(persister) { persister.manager }
        },
      }.merge(options))
    end

    def has_automation_manager_inventory_root_groups(options = {})
      has_ems_folders({
        :model_class    => provider_module::AutomationManager::InventoryRootGroup,
        :association    => :inventory_root_groups,
        :builder_params => {
          :manager => ->(persister) { persister.manager }
        },
      }.merge(options))
    end
  end
end
