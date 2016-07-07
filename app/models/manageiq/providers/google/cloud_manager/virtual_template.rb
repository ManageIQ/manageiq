class ManageIQ::Providers::Google::CloudManager::VirtualTemplate < ::ManageIQ::Providers::CloudManager::VirtualTemplate
  validates :cloud_network, :availability_zone, :ems_ref, :flavor, :presence => true

  belongs_to :cloud_network
  belongs_to :availability_zone
  belongs_to :flavor
end
