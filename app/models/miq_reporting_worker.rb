class MiqReportingWorker < MiqQueueWorkerBase
  self.required_roles       = ["reporting"]
  self.default_queue_name   = "reporting"
end
