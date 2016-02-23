class ManageIQ::Providers::Openstack::CloudManager::CloudSubnet < ::CloudSubnet
  belongs_to :network_router, :class_name => "ManageIQ::Providers::Openstack::CloudManager::NetworkRouter"

  has_one :public_network, :through => :network_router, :source => :cloud_network
end
