class ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet < ::CloudSubnet
  belongs_to :network_router, :class_name => "ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter"

  has_one :public_network, :through => :network_router, :source => :cloud_network

  # TODO(lsmola) NetworkManager, once all providers use network manager we don't need this
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
end
