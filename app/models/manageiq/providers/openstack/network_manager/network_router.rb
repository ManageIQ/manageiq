class ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter < ::NetworkRouter
  belongs_to :cloud_network
  alias public_network cloud_network

  has_many :floating_ips, :through => :cloud_network
  has_many :cloud_networks, :through => :cloud_subnets
  alias private_networks cloud_networks
end
