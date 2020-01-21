module MiqServer::WorkerManagement::Monitor::Validation
  extend ActiveSupport::Concern

  def validate_worker(w)
    return true if MiqEnvironment::Command.is_podified?

    if exceeded_heartbeat_threshold?(w)
      stop_worker(w, MiqServer::NOT_RESPONDING)
      return false
    end

    return true if worker_get_monitor_status(w.pid)

    if exceeded_memory_threshold?(w)
      stop_worker(w)
      return false
    end

    true
  end

  def exceeded_heartbeat_threshold?(w)
    time_threshold = get_time_threshold(w)
    if time_threshold.seconds.ago.utc > w.last_heartbeat
      msg = "#{w.format_full_log_msg} has not responded in #{Time.now.utc - w.last_heartbeat} seconds, restarting worker"
      _log.error(msg)
      MiqEvent.raise_evm_event_queue(w.miq_server, "evm_worker_not_responding", :event_details => msg, :type => w.class.name)
      return true
    end
    false
  end

  def exceeded_memory_threshold?(w)
    memory_threshold = get_memory_threshold(w)

    # Unique set size is only implemented on linux
    usage = w.unique_set_size || w.memory_usage
    if MiqWorker::STATUSES_CURRENT.include?(w.status) && usage_exceeds_threshold?(usage, memory_threshold)
      msg = "#{w.format_full_log_msg} process memory usage [#{usage}] exceeded limit [#{memory_threshold}], requesting worker to exit"
      _log.warn(msg)
      full_data = {
        :name             => w.type,
        :memory_usage     => ActiveSupport::NumberHelper.number_to_human_size(usage),
        :memory_threshold => ActiveSupport::NumberHelper.number_to_human_size(memory_threshold),
      }
      MiqEvent.raise_evm_event_queue(w.miq_server, "evm_worker_memory_exceeded",
                                     :event_details => msg,
                                     :type          => w.class.name,
                                     :full_data     => full_data)
      return true
    end
    false
  end

  private

  def usage_exceeds_threshold?(usage, threshold)
    return false unless usage.kind_of?(Numeric)
    return false unless threshold.kind_of?(Numeric)
    return false unless threshold > 0
    usage > threshold
  end
end
