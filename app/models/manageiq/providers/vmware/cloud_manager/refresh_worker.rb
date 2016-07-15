class ManageIQ::Providers::Vmware::CloudManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner
end
