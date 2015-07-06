class ManageIQ::Providers::Vmware::InfraManager::MetricsCollectorWorker::Runner < ManageIQ::Providers::BaseManager::MetricsCollectorWorker::Runner
  self.require_vim_broker = true
end
