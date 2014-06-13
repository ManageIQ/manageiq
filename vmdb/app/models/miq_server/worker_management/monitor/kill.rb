module MiqServer::WorkerManagement::Monitor::Kill
  extend ActiveSupport::Concern

  def kill_timed_out_worker_quiesce
    log_prefix = "MIQ(MiqServer.kill_timed_out_worker_quiesce)"
    killed_workers = []
    self.miq_workers.each do |w|
      if quiesce_timed_out?(w.quiesce_time_allowance)
        $log.warn("#{log_prefix} Timed out quiesce of #{w.format_full_log_msg} after #{w.quiesce_time_allowance} seconds")
        w.kill
        worker_delete(w.pid)
        killed_workers << w
      end
    end
    self.miq_workers.delete(*killed_workers) unless killed_workers.empty?
  end

  def kill_all_workers
    return unless self.is_local?

    killed_workers = []
    self.miq_workers.each do |w|
      if MiqWorker::STATUSES_CURRENT_OR_STARTING.include?(w.status)
        w.kill
        worker_delete(w.pid)
        killed_workers << w
      end
    end
    self.miq_workers.delete(*killed_workers) unless killed_workers.empty?
  end
end
