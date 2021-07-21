class MiqEventHandler < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.required_roles               = ["event"]
  self.default_queue_name           = "ems"
  self.miq_messaging_subscribe_mode = "topic"

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_EVENT_HANDLERS
  end
end
