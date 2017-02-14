class ManageIQ::Providers::AnsibleTower::Inventory::Target::AutomationManager < ManagerRefresh::Inventory::Target
  def inventory_groups
    collections[:inventory_groups] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ManageIQ::Providers::AutomationManager::InventoryRootGroup,
      :association    => :inventory_root_groups,
      :parent         => target,
      :builder_params => {:manager => manager}
    )
  end

  def configured_systems
    collections[:configured_systems] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfiguredSystem,
      :association    => :configured_systems,
      :parent         => target,
      :manager_ref    => [:manager_ref],
      :builder_params => {:manager => manager}
    )
  end

  def configuration_scripts
    collections[:configuration_scripts] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ManageIQ::Providers::AnsibleTower::AutomationManager::ConfigurationScript,
      :association    => :configuration_scripts,
      :parent         => target,
      :manager_ref    => [:manager_ref],
      :builder_params => {:manager => manager}
    )
  end

  def configuration_script_sources
    collections[:configuration_script_sources] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ConfigurationScriptSource,
      :association    => :configuration_script_sources,
      :manager_ref    => [:manager_ref],
      :parent         => target,
      :builder_params => {:manager => manager}
    )
  end

  def playbooks
    collections[:playbooks] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ManageIQ::Providers::AnsibleTower::AutomationManager::Playbook,
      :association    => :configuration_script_payloads,
      :manager_ref    => [:manager_ref],
      :parent         => target,
      :builder_params => {:manager => manager}
    )
  end

  def credentials
    collections[:credentials] ||= ManagerRefresh::InventoryCollection.new(
      :model_class    => ManageIQ::Providers::AutomationManager::Authentication,
      :association    => :credentials,
      :manager_ref    => [:manager_ref],
      :parent         => @root,
      :builder_params => {:resource => @root}
    )
  end
end
