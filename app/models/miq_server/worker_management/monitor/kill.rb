module MiqServer::WorkerManagement::Monitor::Kill
  extend ActiveSupport::Concern

  def kill_all_workers
    return unless my_server.is_local?

    kill_unknown_worker_processes
    kill_worker_processes
  end

  private

  def kill_unknown_worker_processes
    # We try, but forget to write migrations to delete orphaned worker class rows, causing this method
    # to blow up and cause the server to continually fail to start.
    # This is called very early from evm_application and ensures we attempt to call MiqWorker#kill
    # to remove the problematic rows, and their in flight queue messages.
    bad_workers = miq_workers.where.not(:type => MiqWorker.descendants.map(&:name))
    if bad_workers.size.positive?
      begin
        MiqWorker.inheritance_column = "__disabled"
        kill_worker_processes(bad_workers)
      ensure
        MiqWorker.inheritance_column = "type"
      end
    end
  end

  def kill_worker_processes(workers = miq_workers)
    remove_workers(workers) do |w|
      w.kill_process if w.current_or_starting?
    end
  end
end
