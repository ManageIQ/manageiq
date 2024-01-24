class MiqScheduleWorker < MiqWorker
  include MiqWorker::ReplicaPerWorker

  self.workers = 1

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_SCHEDULE_WORKERS
  end
end
