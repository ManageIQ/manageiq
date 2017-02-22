module ManageIQ::Providers::AnsibleTower::Shared::Inventory::Persister::AutomationManager
  extend ActiveSupport::Concern
  include ManagerRefresh::Inventory::AutomationManager

  included do
    has_automation_manager_credentials
    has_automation_manager_configuration_scripts
    has_automation_manager_configuration_script_sources
    has_automation_manager_configuration_script_payloads :model_class => ManageIQ::Providers::Inflector.provider_module(self)::AutomationManager::Playbook
    has_automation_manager_configured_systems
    has_automation_manager_inventory_root_groups
  end

  def initialize_inventory_collections
    collections[:vms] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => Vm,
      :arel        => Vm,
      :strategy    => :local_db_find_references,
      :manager_ref => [:uid_ems]
    )
  end
end
