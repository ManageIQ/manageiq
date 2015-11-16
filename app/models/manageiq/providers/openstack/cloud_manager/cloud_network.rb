class ManageIQ::Providers::Openstack::CloudManager::CloudNetwork < ::CloudNetwork
  require_nested :Private
  require_nested :Public
end
