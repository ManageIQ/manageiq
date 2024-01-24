class MiqGenericWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  self.default_queue_name = "generic"

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_GENERIC_WORKERS
  end
end
