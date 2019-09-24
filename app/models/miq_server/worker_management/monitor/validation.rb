module MiqServer::WorkerManagement::Monitor::Validation
  extend ActiveSupport::Concern

  def validate_worker(w)
    time_threshold   = get_time_threshold(w)
    memory_threshold = get_memory_threshold(w)

    w.validate_active_messages

    validate_heartbeat(w)

    if time_threshold.seconds.ago.utc > w.last_heartbeat
      msg = "#{w.format_full_log_msg} has not responded in #{Time.now.utc - w.last_heartbeat} seconds, restarting worker"
      _log.error(msg)
      MiqEvent.raise_evm_event_queue(w.miq_server, "evm_worker_not_responding", :event_details => msg, :type => w.class.name)
      restart_worker(w, MiqServer::NOT_RESPONDING)
      return false
    end

    return true unless worker_get_monitor_status(w.pid).nil?

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
      restart_worker(w)
      return false
    end

    true
  end

  def validate_active_messages(processed_worker_ids = [])
    actives = MiqQueue.where(:state => 'dequeue').includes(:handler)
    actives.each do |msg|
      next if processed_worker_ids.include?(msg.handler_id)

      # Exclude messages on starting/started servers
      handler = msg.handler
      handler_server = handler.respond_to?(:miq_server) ? handler.miq_server : handler
      if handler_server.kind_of?(MiqServer) && handler_server != self
        next if [MiqServer::STATUS_STARTED, MiqServer::STATUS_STARTING].include?(handler_server.status)
      end

      msg.check_for_timeout(_log.prefix)
    end
  end

  private

  def usage_exceeds_threshold?(usage, threshold)
    return false unless usage.kind_of?(Numeric)
    return false unless threshold.kind_of?(Numeric)
    return false unless threshold > 0
    usage > threshold
  end
end
