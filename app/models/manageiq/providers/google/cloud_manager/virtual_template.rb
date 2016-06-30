class ManageIQ::Providers::Google::CloudManager::VirtualTemplate < ::ManageIQ::Providers::CloudManager::VirtualTemplate
  validates :cloud_network_id, :availability_zone_id, :ems_ref, :ems_id, :flavor_id, :presence => true
end
