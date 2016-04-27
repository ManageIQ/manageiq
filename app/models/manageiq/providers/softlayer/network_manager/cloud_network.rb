class ManageIQ::Providers::Softlayer::NetworkManager::CloudNetwork < ::CloudNetwork
  require_nested :Private
  require_nested :Public
end
