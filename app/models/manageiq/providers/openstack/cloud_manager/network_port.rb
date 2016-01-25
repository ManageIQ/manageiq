class ManageIQ::Providers::Openstack::CloudManager::NetworkPort < ::NetworkPort
  belongs_to :cloud_subnet, :class_name => "ManageIQ::Providers::Openstack::CloudManager::CloudSubnet"

  has_one :network_router, :through    => :cloud_subnet,
                           :class_name => "ManageIQ::Providers::Openstack::CloudManager::NetworkRouter"
  has_one :public_network, :through => :cloud_subnet
end
