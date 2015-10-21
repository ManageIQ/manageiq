class MiqGenericWorker < MiqQueueWorkerBase
  require_nested :Runner

  self.default_queue_name     = "generic"
  self.check_for_minimal_role = false
  self.workers                = -> { MiqServer.minimal_env? ? 1 : worker_settings[:count] }
end
