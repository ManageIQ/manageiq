class MiqEventHandler < MiqQueueWorkerBase
  require_dependency 'miq_event_handler/runner'

  self.required_roles       = ["event"]
  self.default_queue_name   = "ems"
end
