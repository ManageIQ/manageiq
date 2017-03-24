module ManageIQ::Providers::AnsibleTower::Shared::Inventory::Persister::AutomationManager
  extend ActiveSupport::Concern
  include ManagerRefresh::Inventory::AutomationManager

  included do
    has_automation_manager_credentials
    has_automation_manager_configuration_scripts
    has_automation_manager_configuration_script_sources(
      :model_class => ManageIQ::Providers::Inflector.provider_module(self)::AutomationManager::Project,
      :association => :projects
    )
    has_automation_manager_configuration_script_payloads(
      :model_class => ManageIQ::Providers::Inflector.provider_module(self)::AutomationManager::Playbook,
      :manager_ref => [:project, :manager_ref],
    )
    has_automation_manager_configured_systems
    has_automation_manager_inventory_root_groups
    has_vms :parent => nil, :arel => Vm, :strategy => :local_db_find_references
  end
end
