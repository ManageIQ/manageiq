class MiqReportingWorker < MiqQueueWorkerBase
  require_nested :Runner

  self.required_roles       = ["reporting"]
  self.default_queue_name   = "reporting"
end
