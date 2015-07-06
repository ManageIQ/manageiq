class MiqEventHandler < MiqQueueWorkerBase
  self.required_roles       = ["event"]
  self.default_queue_name   = "ems"
end
