module MiqServer::WorkerManagement::Monitor::Status
  extend ActiveSupport::Concern

  def worker_set_monitor_status(pid, status)
    unless @workers_lock.nil?
      @workers_lock.synchronize(:EX) do
        @workers[pid][:monitor_status] = status if @workers.key?(pid)
      end
    end
  end

  def worker_get_monitor_status(pid)
    @workers_lock.synchronize(:SH) { @workers.fetch_path(pid, :monitor_status) } unless @workers_lock.nil?
  end
end
