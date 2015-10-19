class MiqEventHandler < MiqQueueWorkerBase
  require_nested :Runner

  self.required_roles       = ["event"]
  self.default_queue_name   = "ems"
end
