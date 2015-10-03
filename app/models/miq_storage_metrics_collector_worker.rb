class MiqStorageMetricsCollectorWorker < MiqQueueWorkerBase
  require_dependency 'miq_storage_metrics_collector_worker/runner'

  self.required_roles   = ["storage_metrics_collector"]
  self.default_queue_name = "storage_metrics_collector"
  self.workers      = 1

  def friendly_name
    @friendly_name ||= "Storage Metrics Collector"
  end
end
