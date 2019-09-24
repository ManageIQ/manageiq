class ManageIQ::Providers::BaseManager::MetricsCollectorWorker::Runner < ::MiqQueueWorkerBase::Runner
  self.delay_startup_for_vim_broker = true # NOTE: For ems_metrics_collector role, TODO: only for VMware
end
