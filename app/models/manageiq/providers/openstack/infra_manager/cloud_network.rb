class ManageIQ::Providers::Openstack::InfraManager::CloudNetwork < ::CloudNetwork
  require_nested :Private
  require_nested :Public
end
