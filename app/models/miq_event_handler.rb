class MiqEventHandler < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  self.required_roles               = ["event"]
  self.default_queue_name           = "ems"
  self.miq_messaging_subscribe_mode = "topic"
  self.maximum_workers_count        = 1

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_EVENT_HANDLERS
  end
end
