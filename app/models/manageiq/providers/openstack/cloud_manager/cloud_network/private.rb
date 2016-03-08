class ManageIQ::Providers::Openstack::CloudManager::CloudNetwork::Private < ManageIQ::Providers::Openstack::CloudManager::CloudNetwork
  include CloudNetworkPrivateMixin

  has_many :cloud_subnets, :class_name  => "ManageIQ::Providers::Openstack::CloudManager::CloudSubnet",
                           :foreign_key => :cloud_network_id
  has_many :network_routers, :through => :cloud_subnets
  has_many :public_networks, :through => :cloud_subnets
end
