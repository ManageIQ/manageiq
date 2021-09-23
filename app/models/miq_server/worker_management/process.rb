class MiqServer::WorkerManagement::Process < MiqServer::WorkerManagement::Base
  def cleanup_failed_workers
    check_not_responding
    super
  end

  def check_not_responding
    worker_deleted = false
    miq_workers.each do |worker|
      next unless monitor_reason_not_responding?(worker)
      next unless worker_get_monitor_status(worker.pid) == :waiting_for_stop

      worker_not_responding(worker)
      worker_delete(worker.pid)
      worker.destroy
      worker_deleted = true
    end

    miq_workers.reload if worker_deleted
  end

  def monitor_reason_not_responding?(worker)
    [MiqServer::WorkerManagement::NOT_RESPONDING, MiqServer::WorkerManagement::MEMORY_EXCEEDED].include?(worker_get_monitor_reason(worker.pid)) || worker.stopping_for_too_long?
  end

  def worker_not_responding(worker)
    msg = "#{worker.format_full_log_msg} being killed because it is not responding"
    _log.warn(msg)
    MiqEvent.raise_evm_event_queue(worker.miq_server, "evm_worker_killed", :event_details => msg, :type => worker.class.name)
    worker.kill
  end

  def monitor_active_workers
    # Monitor all remaining current worker records
    miq_workers.where(:status => MiqWorker::STATUSES_CURRENT_OR_STARTING).each do |worker|
      # Push the heartbeat into the database
      persist_last_heartbeat(worker)
      # Check the worker record for heartbeat timeouts
      validate_worker(worker)
    end
  end

  def persist_last_heartbeat(worker)
    last_heartbeat = workers_last_heartbeat(worker)

    if worker.last_heartbeat.nil?
      last_heartbeat ||= Time.now.utc
      worker.update(:last_heartbeat => last_heartbeat)
    elsif !last_heartbeat.nil? && last_heartbeat > worker.last_heartbeat
      worker.update(:last_heartbeat => last_heartbeat)
    end
  end

  def clean_heartbeat_files
    Dir.glob(Rails.root.join("tmp/*.hb")).each { |f| File.delete(f) }
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

  def exceeded_heartbeat_threshold?(worker)
    time_threshold = get_time_threshold(worker)

    if time_threshold.seconds.ago.utc > worker.last_heartbeat
      msg = "#{worker.format_full_log_msg} has not responded in #{Time.now.utc - worker.last_heartbeat} seconds, restarting worker"
      _log.error(msg)
      MiqEvent.raise_evm_event_queue(worker.miq_server, "evm_worker_not_responding", :event_details => msg, :type => worker.class.name)
      return true
    end

    false
  end

  def exceeded_memory_threshold?(worker)
    memory_threshold = get_memory_threshold(worker)

    # Unique set size is only implemented on linux
    usage = worker.unique_set_size || worker.memory_usage

    if MiqWorker::STATUSES_CURRENT.include?(worker.status) && usage_exceeds_threshold?(usage, memory_threshold)
      msg = "#{worker.format_full_log_msg} process memory usage [#{usage}] exceeded limit [#{memory_threshold}], requesting worker to exit"
      _log.warn(msg)
      full_data = {
        :name             => worker.type,
        :memory_usage     => ActiveSupport::NumberHelper.number_to_human_size(usage),
        :memory_threshold => ActiveSupport::NumberHelper.number_to_human_size(memory_threshold),
      }
      MiqEvent.raise_evm_event_queue(worker.miq_server, "evm_worker_memory_exceeded",
                                     :event_details => msg,
                                     :type          => worker.class.name,
                                     :full_data     => full_data)
      return true
    end

    false
  end

  private

  def workers_last_heartbeat(worker)
    File.mtime(worker.heartbeat_file).utc if File.exist?(worker.heartbeat_file)
  end

  def usage_exceeds_threshold?(usage, threshold)
    return false unless usage.kind_of?(Numeric)
    return false unless threshold.kind_of?(Numeric)
    return false unless threshold > 0

    usage > threshold
  end
end
