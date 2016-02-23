class ManageIQ::Providers::Openstack::CloudManager::NetworkRouter < ::NetworkRouter
  belongs_to :cloud_network
  alias_method :public_network, :cloud_network

  has_many :floating_ips, :through => :cloud_network
  has_many :cloud_networks, :through => :cloud_subnets
  alias_method :private_networks, :cloud_networks
end
