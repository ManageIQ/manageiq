class ManageIQ::Providers::Openstack::NetworkManager::NetworkPort < ::NetworkPort
  belongs_to :cloud_subnet, :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet"

  has_one :network_router, :through => :cloud_subnet,
          :class_name => "ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter"
  has_one :public_network, :through => :cloud_subnet
end
