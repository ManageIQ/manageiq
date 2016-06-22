class ManageIQ::Providers::Amazon::CloudManager::VirtualTemplate < ::ManageIQ::Providers::CloudManager::VirtualTemplate
  validates :cloud_subnet_id, :availability_zone_id, :ems_ref, presence: true
end