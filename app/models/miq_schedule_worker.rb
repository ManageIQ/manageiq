class MiqScheduleWorker < MiqWorker
  include MiqWorker::ReplicaPerWorker

  require_nested :Jobs
  require_nested :Runner

  self.check_for_minimal_role = false
  self.workers                = lambda {
    return MiqServer.minimal_env_options.include?('schedule') ? 1 : 0 if MiqServer.minimal_env?
    return 1
  }

  def self.supports_container?
    true
  end
end
