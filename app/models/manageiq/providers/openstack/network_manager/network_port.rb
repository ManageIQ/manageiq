class ManageIQ::Providers::Openstack::NetworkManager::NetworkPort < ::NetworkPort
  has_many :cloud_subnets, :through    => :cloud_subnet_network_ports,
                           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet"
  has_many :network_routers, :through    => :cloud_subnets,
                             :class_name => "ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter"
  has_many :public_networks, :through => :cloud_subnets
end
