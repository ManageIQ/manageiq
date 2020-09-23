class MiqPriorityWorker < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.default_queue_name   = "generic"

  def self.queue_priority
    MiqQueue::HIGH_PRIORITY
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_PRIORITY_WORKERS
  end
end
