class ManageIQ::Providers::AutomationManager::InventoryRootGroup < ManageIQ::Providers::AutomationManager::InventoryGroup
  has_many :configuration_scripts
  has_many :configured_systems

  virtual_column :total_configured_systems, :type => :integer

  scope :with_provider, ->(ems_id) { where(:ems_id => ems_id) }

  def total_configured_systems
    Rbac.filtered(configured_systems).count
  end
end
