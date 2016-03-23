class MiqStorageMetricsCollectorWorker < MiqQueueWorkerBase
  require_nested :Runner

  self.required_roles   = ["storage_metrics_collector"]
  self.default_queue_name = "storage_metrics_collector"
  self.workers      = 1

  def friendly_name
    @friendly_name ||= _("Storage Metrics Collector")
  end
end
