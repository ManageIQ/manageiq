class MiqGenericWorker::Runner < MiqQueueWorkerBase::Runner
  self.delay_startup_for_vim_broker = true # NOTE: For ems_operations and smartstate roles
end
