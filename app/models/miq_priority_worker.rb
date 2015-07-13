class MiqPriorityWorker < MiqQueueWorkerBase
  self.default_queue_name   = "generic"

  def self.queue_priority
    MiqQueue::HIGH_PRIORITY
  end
end
