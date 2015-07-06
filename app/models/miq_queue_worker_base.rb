class MiqQueueWorkerBase < MiqWorker
  def self.queue_priority
    MiqQueue::MIN_PRIORITY
  end
end
