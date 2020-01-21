module MiqServer::WorkerManagement::Monitor::Kill
  extend ActiveSupport::Concern

  def kill_all_workers
    return unless self.is_local?

    remove_unknown_workers
    remove_workers
  end

  private

  def remove_unknown_workers
    # We try, but forget to write migrations to delete orphaned worker class rows, causing this method
    # to blow up and cause the server to continually fail to start.
    # This is called very early from evm_application and ensures we attempt to call MiqWorker#kill
    # to remove the problematic rows, and their in flight queue messages.
    bad_workers = miq_workers.where.not(:type => MiqWorker.descendants.map(&:name))
    if bad_workers.size.positive?
      begin
        MiqWorker.inheritance_column = "__disabled"
        remove_workers(bad_workers)
      ensure
        MiqWorker.inheritance_column = "type"
      end
    end
  end

  def remove_workers(workers = miq_workers)
    killed_workers = []

    workers.each do |w|
      w.kill_process if MiqWorker::STATUSES_CURRENT_OR_STARTING.include?(w.status)
      w.destroy
      worker_delete(w.pid)
      killed_workers << w
    end
    miq_workers.delete(*killed_workers) unless killed_workers.empty?
  end
end
