class MiqServer::WorkerManagement::Process < MiqServer::WorkerManagement
  def sync_from_system
    require "sys/proctable"
    self.miq_processes = Sys::ProcTable.ps.select { |proc| proc.ppid == my_server.pid }
  end

  def sync_starting_workers
    MiqWorker.find_all_starting.to_a
  end

  def sync_stopping_workers
    MiqWorker.find_all_stopping.to_a
  end

  def monitor_workers
    super

    monitor_active_workers
    do_system_limit_exceeded if kill_workers_due_to_resources_exhausted?
  end

  def monitor_active_workers
    # Monitor all remaining current worker records
    miq_workers.find_current_or_starting.each do |worker|
      # Push the heartbeat into the database
      persist_last_heartbeat(worker)
      # Check the worker record for heartbeat timeouts
      validate_worker(worker)
    end
  end

  def kill_workers_due_to_resources_exhausted?
    options = worker_monitor_settings[:kill_algorithm].merge(:type => :kill)
    invoke_algorithm(options)
  end

  def cleanup_failed_workers
    check_not_responding

    super
  end

  def workers_quiesced?
    check_not_responding
    super
  end

  def check_not_responding
    workers_to_check = miq_workers.select do |w|
      monitor_reason_not_responding?(w) &&
        worker_get_monitor_status(w.pid) == :waiting_for_stop
    end

    remove_workers(workers_to_check) do |w|
      worker_not_responding(w)
    end
  end

  def validate_worker(worker)
    if exceeded_heartbeat_threshold?(worker)
      stop_worker(worker, MiqServer::WorkerManagement::NOT_RESPONDING)
      return false
    end

    return true if worker_get_monitor_status(worker.pid)

    if exceeded_memory_threshold?(worker)
      stop_worker(worker)
      return false
    end

    true
  end

  private

  attr_accessor :miq_processes
end
