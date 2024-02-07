class AutomationWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  self.required_roles               = ["automate"]
  self.default_queue_name           = "automate"
  self.maximum_workers_count        = 1

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_GENERIC_WORKERS
  end

  def configure_worker_deployment(definition, replicas = 0)
    super

    definition[:spec][:template][:spec][:serviceAccountName] = "manageiq-automation"
    definition[:spec][:template][:spec][:containers][0][:env] << {:name => "AUTOMATION_JOB_SERVICE_ACCOUNT", :value => ENV.fetch("WORKER_SERVICE_ACCOUNT")}
  end
end
