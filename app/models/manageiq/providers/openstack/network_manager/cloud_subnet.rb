class ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet < ::CloudSubnet
  belongs_to :network_router, :class_name => "ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter"

  has_one :public_network, :through => :network_router, :source => :cloud_network
end
