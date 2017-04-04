module MiqServer::WorkerManagement::Monitor::Kill
  extend ActiveSupport::Concern

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
