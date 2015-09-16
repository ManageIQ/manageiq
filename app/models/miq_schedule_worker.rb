class MiqScheduleWorker < MiqWorker
  require_dependency 'miq_schedule_worker/jobs'
  require_dependency 'miq_schedule_worker/runner'

  self.check_for_minimal_role = false
  self.workers                = lambda {
    return MiqServer.minimal_env_options.include?('schedule') ? 1 : 0 if MiqServer.minimal_env?
    return 1
  }
end
