class MiqScheduleWorker < MiqWorker
  include MiqWorker::ReplicaPerWorker

  require_nested :Jobs
  require_nested :Runner

  self.workers = 1

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_SCHEDULE_WORKERS
  end
end
