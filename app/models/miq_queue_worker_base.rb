class MiqQueueWorkerBase < MiqWorker
  class_attribute :miq_messaging_subscribe_mode

  def self.queue_priority
    MiqQueue::MIN_PRIORITY
  end
end
