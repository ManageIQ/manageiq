class ManageIQ::Providers::Openstack::InfraManager::CloudNetwork::Private < ManageIQ::Providers::Openstack::InfraManager::CloudNetwork
  include CloudNetworkPrivateMixin

  has_many :cloud_subnets, :class_name => "ManageIQ::Providers::Openstack::InfraManager::CloudSubnet", :foreign_key => :cloud_network_id
end
