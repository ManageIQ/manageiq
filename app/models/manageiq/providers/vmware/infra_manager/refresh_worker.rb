class ManageIQ::Providers::Vmware::InfraManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_dependency 'manageiq/providers/vmware/infra_manager/refresh_worker/runner'
end
