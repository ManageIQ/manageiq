class ManageIQ::Providers::SoftLayer::NetworkManager::CloudNetwork < ::CloudNetwork
  require_nested :Private
  require_nested :Public
end
