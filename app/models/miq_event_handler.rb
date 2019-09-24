class MiqEventHandler < MiqQueueWorkerBase
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.required_roles       = ["event"]
  self.default_queue_name   = "ems"

  def self.supports_container?
    true
  end
end
