module ManageIQ::Providers::AnsibleTower::Shared::Inventory::Persister::ConfigurationScriptSource
  extend ActiveSupport::Concern
  include ManagerRefresh::Inventory::AutomationManager

  included do
    has_automation_manager_credentials :complete => false
    has_automation_manager_configuration_script_sources :complete => false
    has_automation_manager_configuration_script_payloads(
      :model_class => ManageIQ::Providers::Inflector.provider_module(self)::AutomationManager::Playbook,
      :parent      => :target
    )
  end
end
