class ManageIQ::Providers::ConfigurationManager::InventoryGroup < EmsFolder
  belongs_to :manager, :foreign_key => "ems_id", :class_name => "ManageIQ::Providers::ConfigurationManager"
end
