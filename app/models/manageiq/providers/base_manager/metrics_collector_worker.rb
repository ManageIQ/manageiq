class ManageIQ::Providers::BaseManager::MetricsCollectorWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker
  include ProviderWorkerMixin
  include PerEmsTypeWorkerMixin

  self.required_roles = ["ems_metrics_collector"]

  def self.normalized_type
    @normalized_type ||= "ems_metrics_collector_worker"
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_METRICS_COLLECTOR_WORKERS
  end
end
