require 'workers/worker_base'
require 'miq-system'

class QueueWorkerBase < WorkerBase
  def after_sync_config
    self.sync_cpu_usage_threshold
    self.sync_dequeue_method
  end

  def sync_cpu_usage_threshold
    @cpu_usage_threshold = self.worker_settings[:cpu_usage_threshold]
  end

  def sync_dequeue_method
    @dequeue_method = (self.worker_settings[:dequeue_method] || :sql).to_sym
  end

  def dequeue_method_via_drb?
    @dequeue_method == :drb
  end

  def thresholds_exceeded?
    return false if @cpu_usage_threshold == 0

    usage = MiqSystem.cpu_usage
    return false if usage.nil?

    if usage > @cpu_usage_threshold
      $log.info("#{self.log_prefix} [#{Process.pid}] System CPU usage [#{usage}] exceeded threshold [#{@cpu_usage_threshold}], sleeping")
      return true
    end

    return false
  end

  def get_message_via_drb
    loop do
      begin
        msg_id, lock_version = @worker_monitor_drb.get_queue_message(@worker.pid)
      rescue DRb::DRbError => err
        do_exit("Error communicating with WorkerMonitor because <#{err.message}>", 1)
      end

      return nil if msg_id.nil?

      msg = MiqQueue.find_by_id(msg_id)
      if msg.nil?
        $log.debug("#{log_prefix} Message id: [#{msg_id}] stale (msg gone), retrying...")
        next
      end

      if msg.lock_version != lock_version
        $log.debug("#{log_prefix} #{MiqQueue.format_short_log_msg(msg)} stale (lock_version mismatch), retrying...")
        next
      end

      # TODO: Possible race condition where task_id is checked in a separate call from dequeueing
      next if msg.task_id && MiqQueue.exists?(:state => MiqQueue::STATE_DEQUEUE, :zone => [nil, MiqServer.my_zone], :task_id => msg.task_id)

      begin
        msg.update_attributes!(:state => MiqQueue::STATE_DEQUEUE, :handler => @worker)
        $log.info("MIQ(MiqQueue.get_via_drb) #{MiqQueue.format_full_log_msg(msg)}, Dequeued in: [#{Time.now - msg.created_on}] seconds")
        return msg
      rescue ActiveRecord::StaleObjectError
        $log.debug("#{log_prefix} #{MiqQueue.format_short_log_msg(msg)} stale, retrying...")
        next
      rescue => err
        raise "#{log_prefix} \"#{err}\" attempting to get next message"
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
    @worker.update_spid!
    if dequeue_method_via_drb? && @worker_monitor_drb
      get_message_via_drb
    else
      get_message_via_sql
    end
  end

  def message_delivery_suspended?
    if self.class.require_vim_broker?
      return true unless MiqVimBrokerWorker.available?
    end

    return false
  end

  def deliver_queue_message(msg)
    self.reset_poll_escalate if self.poll_method == :sleep_poll_escalate

    begin
      $_miq_worker_current_msg = msg
      status, message, result = msg.deliver

      if status == MiqQueue::STATUS_TIMEOUT
        begin
          $log.info("#{self.log_prefix} Reconnecting to DB after timeout error during queue deliver") if $log
          ActiveRecord::Base.connection.reconnect!
        rescue => err
          do_exit("Exiting worker due to timeout error that could not be recovered from...error: #{err.class.name}: #{err.message}", 1)
        end
      end

      msg.delivered(status, message, result) unless status == MiqQueue::STATUS_RETRY
      do_exit("Exiting worker due to timeout error", 1) if status == MiqQueue::STATUS_TIMEOUT
    rescue MiqException::MiqVimBrokerUnavailable
      $log.error("#{self.log_prefix} VimBrokerWorker is not available.  Requeueing message...") if $log
      msg.unget
    ensure
      $_miq_worker_current_msg = nil # to avoid log messages inadvertantly prefixed by previous task_id
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

    emsg = "#{self.log_prefix} Message <#{msg.inspect}> is of unknown type <#{msg.class.to_s}>"
    $log.error(emsg) if $log
    raise emsg
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
end
