class ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public < ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork
  has_many :vms, -> { distinct }, :through => :network_routers
  has_many :network_routers, :foreign_key => :cloud_network_id
  has_many :private_networks, -> { distinct }, :through => :network_routers, :source => :cloud_networks
end
