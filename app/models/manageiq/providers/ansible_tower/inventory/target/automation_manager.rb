class ManageIQ::Providers::AnsibleTower::Inventory::Target::AutomationManager < ManagerRefresh::Inventory::Target
  def inventory_groups
    collections[:inventory_groups] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ManageIQ::Providers::AutomationManager::InventoryRootGroup,
      :association    => :inventory_root_groups,
      :parent         => @root,
      :builder_params => {:manager => @root}
    )
  end

  def configured_systems
    collections[:configured_systems] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem,
      :association    => :configured_systems,
      :parent         => @root,
      :manager_ref    => [:manager_ref],
      :builder_params => {:manager => @root}
    )
  end

  def configuration_scripts
    collections[:configuration_scripts] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript,
      :association    => :configuration_scripts,
      :parent         => @root,
      :manager_ref    => [:manager_ref],
      :builder_params => {:manager => @root}
    )
  end
end
