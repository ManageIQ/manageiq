module MiqServer::WorkerManagement::Monitor::Kill
  extend ActiveSupport::Concern

  def kill_timed_out_worker_quiesce
    killed_workers = []
    miq_workers.each do |w|
      if quiesce_timed_out?(w.quiesce_time_allowance)
        _log.warn("Timed out quiesce of #{w.format_full_log_msg} after #{w.quiesce_time_allowance} seconds")
        w.kill
        worker_delete(w.pid)
        killed_workers << w
      end
    end
    miq_workers.delete(*killed_workers) unless killed_workers.empty?
  end

  def kill_all_workers
    return unless self.is_local?

    killed_workers = []
    miq_workers.each do |w|
      if MiqWorker::STATUSES_CURRENT_OR_STARTING.include?(w.status)
        w.kill
        worker_delete(w.pid)
        killed_workers << w
      end
    end
    miq_workers.delete(*killed_workers) unless killed_workers.empty?
  end
end
