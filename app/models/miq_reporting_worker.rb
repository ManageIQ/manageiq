class MiqReportingWorker < MiqQueueWorkerBase
  require_dependency 'miq_reporting_worker/runner'

  self.required_roles       = ["reporting"]
  self.default_queue_name   = "reporting"
end
