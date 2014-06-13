class MiqGenericWorker < MiqQueueWorkerBase
  self.default_queue_name     = "generic"
  self.check_for_minimal_role = false
  self.workers                = lambda { MiqServer.minimal_env? ? 1 : self.worker_settings[:count] }
end
