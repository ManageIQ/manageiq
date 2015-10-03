class MiqPriorityWorker::Runner < MiqQueueWorkerBase::Runner
  self.wait_for_worker_monitor = false
end
