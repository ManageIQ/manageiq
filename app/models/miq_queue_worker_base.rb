class MiqQueueWorkerBase < MiqWorker
  require_dependency 'miq_queue_worker_base/runner'

  def self.queue_priority
    MiqQueue::MIN_PRIORITY
  end
end
