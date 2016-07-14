class ManageIQ::Providers::ConfigurationManager::InventoryGroup < EmsFolder
  belongs_to :manager, :foreign_key => "ems_id", :class_name => "ManageIQ::Providers::ConfigurationManager"

  virtual_column :total_configured_systems, :type => :integer

  def total_configured_systems
    Rbac.filtered(configured_systems).count
  end
end
