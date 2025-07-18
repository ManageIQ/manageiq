require 'miq-system'

class MiqQueueWorkerBase::Runner < MiqWorker::Runner
  def after_sync_config
    sync_dequeue_method
  end

  def sync_dequeue_method
    previous_dequeue_method = @dequeue_method
    @dequeue_method = (worker_settings[:dequeue_method] || :sql).to_sym

    dequeue_method_changed(previous_dequeue_method) if @dequeue_method != previous_dequeue_method
  end

  def dequeue_method_via_drb?
    @dequeue_method == :drb && drb_dequeue_available?
  end

  def dequeue_method_via_miq_messaging?
    @dequeue_method == :miq_messaging && miq_messaging_dequeue_available?
  end

  def dequeue_method_changed(previous_dequeue_method)
    @listener_thread&.kill if previous_dequeue_method == :miq_messaging
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
        msg.update!(:state => MiqQueue::STATE_DEQUEUE, :handler => @worker)
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
        :role       => @worker.required_roles.presence,
        :priority   => @worker.class.queue_priority
      )
      return msg unless msg == :stale
    end
  end

  def get_message_via_miq_messaging
    @message_queue ||= Queue.new
    @message_queue.pop unless @message_queue.empty?
  end

  def get_message
    if dequeue_method_via_miq_messaging?
      get_message_via_miq_messaging
    elsif dequeue_method_via_drb? && @worker_monitor_drb
      get_message_via_drb
    else
      get_message_via_sql
    end
  end

  def deliver_queue_message(msg, &block)
    reset_poll_escalate if poll_method == :sleep_poll_escalate

    begin
      $_miq_worker_current_msg = msg
      Thread.current[:tracking_label] = msg.tracking_label || msg.task_id
      heartbeat_message_timeout(msg)
      status, message, result = msg.deliver(&block)

      if status == MiqQueue::STATUS_TIMEOUT
        begin
          _log.info("#{log_prefix} Reconnecting to DB after timeout error during queue deliver")

          ActiveRecord::Base.postgresql_ssl_friendly_base_reconnect
          @worker.update_spid!
        rescue => err
          do_exit("Exiting worker due to timeout error that could not be recovered from...error: #{err.class.name}: #{err.message}", 1)
        end
      end

      msg.delivered(status, message, result) unless status == MiqQueue::STATUS_RETRY
      do_exit("Exiting worker due to timeout error", 1) if status == MiqQueue::STATUS_TIMEOUT
    ensure
      $_miq_worker_current_msg = nil # to avoid log messages inadvertantly prefixed by previous task_id
      Thread.current[:tracking_label] = nil
    end
  end

  def deliver_message(msg)
    case msg
    when MiqQueue
      deliver_queue_message(msg)
    when ManageIQ::Messaging::ReceivedMessage
      process_miq_messaging_message(msg)
    when String
      process_message(msg)
    else
      _log.error("#{log_prefix} Message <#{msg.inspect}> is of unknown type <#{msg.class}>")
      raise _("%{log} Message <%{message}> is of unknown type <%{type}>") %
            {:log => log_prefix, :message => msg.inspect, :type => msg.class}
    end
  end

  def do_work
    register_worker_with_worker_monitor if dequeue_method_via_drb?
    ensure_miq_listener_thread!         if dequeue_method_via_miq_messaging?

    # Keep collecting messages from the queue until the queue is empty,
    #   so we don't sleep in between messages
    loop do
      heartbeat
      msg = get_message
      break if msg.nil?

      deliver_message(msg)
    end
  end

  private

  def register_worker_with_worker_monitor
    worker_monitor_drb.register_worker(@worker.pid, @worker.class.name, @worker.queue_name)
  rescue DRb::DRbError => err
    do_exit("Failed to register worker with worker monitor: #{err.class.name}: #{err.message}", 1)
  end

  def drb_dequeue_available?
    @drb_dequeue_available ||=
      begin
        server.drb_uri.present? && worker_monitor_drb.respond_to?(:register_worker)
      rescue DRb::DRbError
        false
      end
  end

  def miq_messaging_dequeue_available?
    MiqQueue.messaging_type != "miq_queue" && MiqQueue.messaging_client(self.class.name).present?
  end

  def process_miq_messaging_message(_msg)
    raise NotImplementedError, 'Must be implemented in subclass'
  end

  def ensure_miq_listener_thread!
    @miq_listener_thread = nil if @miq_listener_thread && !@miq_listener_thread.alive?

    miq_listener_thread
  end

  def miq_listener_thread
    @miq_listener_thread ||= Thread.new { miq_messaging_listener_thread }
  end

  def miq_messaging_listener_thread
    loop do
      send(:"miq_messaging_subscribe_#{@worker.class.miq_messaging_subscribe_mode}") do |msg|
        @message_queue << msg
      end
    rescue => err
      _log.warn("miq_messaging_listener_thread error [#{err}]")
    end
  end

  def miq_messaging_subscribe_topic(&block)
    messaging_client = MiqQueue.messaging_client(self.class.name)
    messaging_client.subscribe_topic(:service => "manageiq.#{@worker.queue_name}", :persist_ref => @worker.guid, &block)
  end

  def miq_messaging_subscribe_queue(&block)
    messaging_client = MiqQueue.messaging_client(self.class.name)
    messaging_client.subscribe_messages(:service => "manageiq.#{@worker.queue_name}") do |messages|
      messages.each(&block)
    end
  end

  # Only for file based heartbeating
  def heartbeat_message_timeout(message)
    if message.msg_timeout
      timeout = worker_settings[:poll] + message.msg_timeout
      systemd_worker? ? worker.sd_notify_watchdog_usec(timeout) : heartbeat_to_file(timeout)
    end
  end
end
