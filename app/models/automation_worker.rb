class AutomationWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.required_roles               = ["automate"]
  self.default_queue_name           = "automate"
  self.maximum_workers_count        = 1

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_GENERIC_WORKERS
  end
end
