class MiqReportingWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.required_roles       = ["reporting"]
  self.default_queue_name   = "reporting"

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_REPORTING_WORKERS
  end
end
