class AutomationWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.required_roles               = ["automate"]
  self.default_queue_name           = "automate"
  self.maximum_workers_count        = 1

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_GENERIC_WORKERS
  end

  def configure_worker_deployment(definition, replicas = 0)
    super

    definition[:spec][:template][:spec][:serviceAccountName] = "manageiq-automation"
  end
end
