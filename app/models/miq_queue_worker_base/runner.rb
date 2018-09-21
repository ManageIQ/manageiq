require 'miq-system'

class MiqQueueWorkerBase::Runner < MiqWorker::Runner
  def after_sync_config
    sync_cpu_usage_threshold
    sync_dequeue_method
  end

  def sync_cpu_usage_threshold
    @cpu_usage_threshold = worker_settings[:cpu_usage_threshold]
  end

  def sync_dequeue_method
    @dequeue_method = (worker_settings[:dequeue_method] || :sql).to_sym
  end

  def dequeue_method_via_drb?
    @dequeue_method == :drb
  end

  def thresholds_exceeded?
    return false if @cpu_usage_threshold == 0

    usage = MiqSystem.cpu_usage
    return false if usage.nil?

    if usage > @cpu_usage_threshold
      _log.info("#{log_prefix} [#{Process.pid}] System CPU usage [#{usage}] exceeded threshold [#{@cpu_usage_threshold}], sleeping")
      return true
    end

    false
  end

  def get_message_via_drb
    loop do
      begin
        msg_id, lock_version = worker_monitor_drb.get_queue_message(@worker.pid)
      rescue DRb::DRbError => err
        do_exit("Error communicating with WorkerMonitor because <#{err.message}>", 1)
      end

      return nil if msg_id.nil?

      msg = MiqQueue.find_by(:id => msg_id)
      if msg.nil?
        _log.debug("#{log_prefix} Message id: [#{msg_id}] stale (msg gone), retrying...")
        next
      end

      if msg.lock_version != lock_version
        _log.debug("#{log_prefix} #{MiqQueue.format_short_log_msg(msg)} stale (lock_version mismatch), retrying...")
        next
      end

      # TODO: Possible race condition where task_id is checked in a separate call from dequeueing
      next if msg.task_id && MiqQueue.exists?(:state => MiqQueue::STATE_DEQUEUE, :zone => [nil, MiqServer.my_zone], :task_id => msg.task_id)

      begin
        msg.update_attributes!(:state => MiqQueue::STATE_DEQUEUE, :handler => @worker)
        _log.info("#{MiqQueue.format_full_log_msg(msg)}, Dequeued in: [#{Time.now - msg.created_on}] seconds")
        return msg
      rescue ActiveRecord::StaleObjectError
        _log.debug("#{log_prefix} #{MiqQueue.format_short_log_msg(msg)} stale, retrying...")
        next
      rescue => err
        msg.update_column(:state, MiqQueue::STATUS_ERROR)
        raise _("%{log} \"%{error}\" attempting to get next message") % {:log => log_prefix, :error => err}
      end
    end
  end

  def get_message_via_sql
    loop do
      msg = MiqQueue.get(
        :queue_name => @worker.queue_name,
        :role       => @active_roles,
        :priority   => @worker.class.queue_priority
      )
      return msg unless msg == :stale
      heartbeat
    end
  end

  def get_message
    if dequeue_method_via_drb? && @worker_monitor_drb
      get_message_via_drb
    else
      get_message_via_sql
    end
  end

  def message_delivery_suspended?
    self.class.delay_queue_delivery_for_vim_broker? && !MiqVimBrokerWorker.available?
  end

  def deliver_queue_message(msg)
    reset_poll_escalate if poll_method == :sleep_poll_escalate

    begin
      $_miq_worker_current_msg = msg
      Thread.current[:tracking_label] = msg.tracking_label || msg.task_id
      heartbeat_message_timeout(msg)
      status, message, result = msg.deliver

      if status == MiqQueue::STATUS_TIMEOUT
        begin
          _log.info("#{log_prefix} Reconnecting to DB after timeout error during queue deliver")

          # Remove the connection and establish a new one since reconnect! doesn't always play nice with SSL postgresql connections
          spec_name = ActiveRecord::Base.connection_specification_name
          ActiveRecord::Base.establish_connection(ActiveRecord::Base.remove_connection(spec_name))
          @worker.update_spid!
        rescue => err
          do_exit("Exiting worker due to timeout error that could not be recovered from...error: #{err.class.name}: #{err.message}", 1)
        end
      end

      msg.delivered(status, message, result) unless status == MiqQueue::STATUS_RETRY
      do_exit("Exiting worker due to timeout error", 1) if status == MiqQueue::STATUS_TIMEOUT
    rescue MiqException::MiqVimBrokerUnavailable
      _log.error("#{log_prefix} VimBrokerWorker is not available.  Requeueing message...")
      msg.unget
    ensure
      $_miq_worker_current_msg = nil # to avoid log messages inadvertantly prefixed by previous task_id
      Thread.current[:tracking_label] = nil
      #
      # This tells the broker to release any memory being held on behalf of this process
      # and reset the global broker handle ($vim_broker_client).
      # This is a NOOP if global broker handle is not set.
      #
      clean_broker_connection
    end
  end

  def deliver_message(msg)
    return deliver_queue_message(msg) if msg.kind_of?(MiqQueue)
    return process_message(msg)       if msg.kind_of?(String)

    _log.error("#{log_prefix} Message <#{msg.inspect}> is of unknown type <#{msg.class}>")
    raise _("%{log} Message <%{message}> is of unknown type <%{type}>") % {:log     => log_prefix,
                                                                           :message => msg.inspect,
                                                                           :type    => msg.class}
  end

  def do_work
    # Keep collecting messages from the queue until the queue is empty,
    #   so we don't sleep in between messages
    loop do
      heartbeat
      break if thresholds_exceeded?
      break if message_delivery_suspended?
      msg = get_message
      break if msg.nil?
      deliver_message(msg)
    end
  end

  private

  # Only for file based heartbeating
  def heartbeat_message_timeout(message)
    if ENV["WORKER_HEARTBEAT_METHOD"] == "file" && message.msg_timeout
      timeout = worker_settings[:poll] + message.msg_timeout
      heartbeat_to_file(timeout)
    end
  end
end
