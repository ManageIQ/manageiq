class MiqGenericWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.default_queue_name = "generic"

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_GENERIC_WORKERS
  end
end
