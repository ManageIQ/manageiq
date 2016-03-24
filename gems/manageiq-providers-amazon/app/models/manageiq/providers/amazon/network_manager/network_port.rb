class ManageIQ::Providers::Amazon::NetworkManager::NetworkPort < ::NetworkPort
  has_many :cloud_subnets, :through => :cloud_subnet_network_ports, :class_name => "ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet"

  has_many :network_routers, :through => :cloud_subnets,
           :class_name => "ManageIQ::Providers::Amazon::NetworkManager::NetworkRouter"
end
