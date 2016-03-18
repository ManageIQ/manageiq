class ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private < ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork
  include CloudNetworkPrivateMixin

  has_many :cloud_subnets, :class_name  => "ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet",
                           :foreign_key => :cloud_network_id
  has_many :network_routers, :through => :cloud_subnets
  has_many :public_networks, :through => :cloud_subnets
end
