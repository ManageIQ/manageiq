class ManageIQ::Providers::Openstack::InfraManager::CloudSubnet < ::CloudSubnet
  has_one :public_network, :through => :network_router, :source => :cloud_network
end
