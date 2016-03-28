class MiqEmsMetricsProcessorWorker < MiqQueueWorkerBase
  require_nested :Runner

  self.required_roles       = ["ems_metrics_processor"]
  self.default_queue_name   = "ems_metrics_processor"

  def friendly_name
    @friendly_name ||= "C&U Metrics Processor"
  end
end
