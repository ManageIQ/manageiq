class ManageIQ::Providers::SoftLayer::CloudManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner
end
