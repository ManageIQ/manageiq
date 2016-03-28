class ManageIQ::Providers::Oracle::InfraManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner
end
