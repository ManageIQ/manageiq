class ManageIQ::Providers::AutomationManager::InventoryRootGroup < ManageIQ::Providers::AutomationManager::InventoryGroup
  has_many :configuration_scripts
  has_many :configured_systems

  virtual_column :total_configured_systems, :type => :integer

  def total_configured_systems
    Rbac.filtered(configured_systems).count
  end
end
