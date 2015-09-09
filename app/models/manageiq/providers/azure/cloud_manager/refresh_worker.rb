class ManageIQ::Providers::Azure::CloudManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_dependency 'manageiq/providers/azure/cloud_manager/refresh_worker/runner'
end
