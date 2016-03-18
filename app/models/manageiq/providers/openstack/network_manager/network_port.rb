class ManageIQ::Providers::Openstack::NetworkManager::NetworkPort < ::NetworkPort
  belongs_to :cloud_subnet, :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet"

  has_one :network_router, :through    => :cloud_subnet,
          :class_name => "ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter"
  has_one :public_network, :through => :cloud_subnet

  # TODO(lsmola) NetworkManager, once all providers use network manager we don't need this
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
end
