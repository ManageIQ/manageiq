require 'workers/ems_refresh_worker'

class EmsRefreshWorkerVmware < EmsRefreshWorker
  self.require_vim_broker = true

  def do_before_work_loop
    # Override Standard EmsRefreshWorker's method of queueing up a Refresh
    # This will be done by the VimBrokerWorker, when he is ready.
  end

end
