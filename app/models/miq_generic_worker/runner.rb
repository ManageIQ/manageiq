class MiqGenericWorker::Runner < MiqQueueWorkerBase::Runner
  self.wait_for_worker_monitor = true # NOTE: Really means wait for broker to start because of ems_operations and smartstate roles
end
