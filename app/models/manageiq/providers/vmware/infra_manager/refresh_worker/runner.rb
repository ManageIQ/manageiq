class ManageIQ::Providers::Vmware::InfraManager::RefreshWorker::Runner < ManageIQ::Providers::BaseManager::RefreshWorker::Runner
  self.require_vim_broker = true

  def do_before_work_loop
    # Override Standard EmsRefreshWorker's method of queueing up a Refresh
    # if the VimBrokerWorker isn't available yet.
    # This will be done by the VimBrokerWorker, when he is ready.
    #
    # If the VimBrokerWorker is running already then queue up an initial refresh
    super if MiqVimBrokerWorker.available?
  end
end
