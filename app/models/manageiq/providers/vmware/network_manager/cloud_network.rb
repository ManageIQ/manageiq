class ManageIQ::Providers::Vmware::NetworkManager::CloudNetwork < ::CloudNetwork
  require_nested :VappNet
  require_nested :OrgVdcNet
end
