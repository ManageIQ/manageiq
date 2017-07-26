class MiqSmartProxyWorker::Runner < MiqQueueWorkerBase::Runner
  self.delay_startup_for_vim_broker = true # NOTE: For smartproxy role
end
