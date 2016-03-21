class ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork < ::CloudNetwork
  require_nested :Private
  require_nested :Public
end
