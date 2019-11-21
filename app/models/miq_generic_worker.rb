class MiqGenericWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.default_queue_name     = "generic"
  self.check_for_minimal_role = false
  self.workers                = -> { MiqServer.minimal_env? ? 1 : worker_settings[:count] }

  def self.supports_container?
    true
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_GENERIC_WORKERS
  end
end
