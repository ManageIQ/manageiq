class ManageIQ::Providers::ConfigurationManager::InventoryRootGroup < ManageIQ::Providers::ConfigurationManager::InventoryGroup
  has_many :configuration_scripts
end
