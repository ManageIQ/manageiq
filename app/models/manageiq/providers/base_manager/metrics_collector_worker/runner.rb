class ManageIQ::Providers::BaseManager::MetricsCollectorWorker::Runner < ::MiqQueueWorkerBase::Runner
  self.wait_for_worker_monitor = true # NOTE: Really means wait for broker to start for ems_metrics_collector role, TODO: only for VMware
end
