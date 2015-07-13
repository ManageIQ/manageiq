class ManageIQ::Providers::Amazon::CloudManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_dependency 'manageiq/providers/amazon/cloud_manager/refresh_worker/runner'
end
