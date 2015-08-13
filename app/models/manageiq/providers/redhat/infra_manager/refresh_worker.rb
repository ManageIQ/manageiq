class ManageIQ::Providers::Redhat::InfraManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_dependency 'manageiq/providers/redhat/infra_manager/refresh_worker/runner'
end
