class MiqAutomateWorker < MiqQueueWorkerBase
  self.default_queue_name     = 'automate'
  self.check_for_minimal_role = false
  self.required_roles         = ['automate']
  self.workers                = -> { MiqServer.minimal_env? ? 1 : worker_settings[:count] }

  def friendly_name
    @friendly_name ||= 'Automate Worker'
  end
end
