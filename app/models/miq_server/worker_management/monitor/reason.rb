module MiqServer::WorkerManagement::Monitor::Reason
  extend ActiveSupport::Concern

  MEMORY_EXCEEDED = :memory_exceeded
  NOT_RESPONDING  = :not_responding

  def worker_set_monitor_reason(pid, reason)
    @workers_lock.synchronize(:EX) do
      @workers[pid][:monitor_reason] = reason if @workers.key?(pid)
    end unless @workers_lock.nil?
  end

  def worker_get_monitor_reason(pid)
    @workers_lock.synchronize(:SH) { @workers.fetch_path(pid, :monitor_reason) } unless @workers_lock.nil?
  end
end
