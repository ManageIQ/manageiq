class ManageIQ::Providers::AnsibleTower::Inventory::Target::AutomationManager < ManagerRefresh::Inventory::Target
  def automation
    ManageIQ::Providers::AnsibleTower::InventoryCollectionDefault::AutomationManager
  end

  def initialize_inventory_collections
    add_inventory_collections(
      automation,
      %i(inventory_groups configured_systems configuration_scripts configuration_script_sources playbooks),
      :builder_params => {:manager => manager}
    )

    add_inventory_collections(
      automation,
      %i(credentials),
      :builder_params => {:resource => @root}
    )
  end
end
