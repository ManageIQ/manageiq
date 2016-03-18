class ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter < ::NetworkRouter
  belongs_to :cloud_network
  alias public_network cloud_network

  has_many :floating_ips, :through => :cloud_network
  has_many :cloud_networks, :through => :cloud_subnets
  alias private_networks cloud_networks

  # TODO(lsmola) NetworkManager, once all providers use network manager we don't need this
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
end
