class MiqPriorityWorker < MiqQueueWorkerBase
  require_dependency 'miq_priority_worker/runner'

  self.default_queue_name   = "generic"

  def self.queue_priority
    MiqQueue::HIGH_PRIORITY
  end
end
