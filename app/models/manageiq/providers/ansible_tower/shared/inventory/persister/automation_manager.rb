module ManageIQ::Providers::AnsibleTower::Shared::Inventory::Persister::AutomationManager
  def automation
    ManageIQ::Providers::Inflector.provider_module(manager.class)::InventoryCollectionDefault::AutomationManager
  end

  def initialize_inventory_collections
    add_inventory_collections(
      automation,
      %i(inventory_root_groups configured_systems configuration_scripts configuration_script_sources configuration_script_payloads),
      :builder_params => {:manager => manager}
    )

    add_inventory_collections(
      automation,
      %i(credentials),
      :builder_params => {:resource => manager}
    )

    collections[:vms] = ::ManagerRefresh::InventoryCollection.new(
      :model_class => Vm,
      :arel        => Vm,
      :strategy    => :local_db_find_references,
      :manager_ref => [:uid_ems]
    )
  end
end
