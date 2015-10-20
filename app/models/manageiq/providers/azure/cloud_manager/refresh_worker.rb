class ManageIQ::Providers::Azure::CloudManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner
end
