require 'workers/worker_base'
require 'thread'

class EventCatcherHandledException < StandardError
end

class EventCatcher < WorkerBase
  self.wait_for_worker_monitor = false

  OPTIONS_PARSER_SETTINGS = WorkerBase::OPTIONS_PARSER_SETTINGS + [
    [:ems_id, 'EMS Instance ID', String],
  ]

  def after_initialize
    @ems = ExtManagementSystem.find(@cfg[:ems_id])
    do_exit("Unable to find instance for EMS ID [#{@cfg[:ems_id]}].", 1) if @ems.nil?
    do_exit("EMS ID [#{@cfg[:ems_id]}] failed authentication check.", 1) unless @ems.authentication_check

    # Get the filtered events from the event_handling config
    @filtered_events = VMDB::Config.new("event_handling").config[:filtered_events]
    @filtered_events = @filtered_events.each_with_object([]) { |(k, v), ary| ary << k.to_s if v.nil? }
    $log.info "#{log_prefix} Event Catcher skipping the following events:"
    $log.log_hashes(@filtered_events.sort)

    # Global Work Queue
    @queue = Queue.new
  end

  def do_before_work_loop
    @tid = start_event_monitor
  end

  def log_prefix
    @log_prefix ||= "MIQ(#{self.class.name}) EMS [#{@ems.ipaddress}] as [#{@ems.authentication_userid}]"
  end

  def before_exit(message, exit_code)
    @exit_requested = true

    #
    # Stop the Event Monitor
    #
    safe_log("#{message} Stopping Event Monitor Thread.")
    stop_event_monitor

    #
    # Wait for the Event Monitor Thread to complete (timeout after 10 seconds)
    #
    unless @tid.nil?
      safe_log("#{message} Waiting for Event Monitor Thread to Stop.")
      @tid.join(self.worker_settings[:ems_event_thread_shutdown_timeout]) rescue nil
    end

    #
    # Drain the Queue of the Event Monitor
    #
    if @queue
      safe_log("#{message} Draining Event Queue.")
      drain_queue rescue nil
    end
  end

  def filtered_events
    @filtered_events
  end

  def stop_event_monitor
    raise NotImplementedError, "must be implemented in subclass"
  end

  def event_monitor_handle
    raise NotImplementedError, "must be implemented in subclass"
  end

  def monitor_events
    raise NotImplementedError, "must be implemented in subclass"
  end

  def process_event
    raise NotImplementedError, "must be implemented in subclass"
  end

  def start_event_monitor
    @log_prefix = nil
    @exit_requested = false

    begin
      $log.info("#{self.log_prefix} Validating Connection/Credentials")
      @ems.verify_credentials
    rescue => err
      $log.warn("#{self.log_prefix} #{err.message}")
      return nil
    end

    $log.info("#{self.log_prefix} Starting Event Monitor Thread")

    tid = Thread.new do
      begin
        monitor_events
      rescue EventCatcherHandledException
        Thread.exit
      rescue => err
        $log.error("#{self.log_prefix} Event Monitor Thread aborted because [#{err.message}]")
        $log.log_backtrace(err) unless err.kind_of?(Errno::ECONNREFUSED)
        Thread.exit
      end
    end

    $log.info("#{self.log_prefix} Started Event Monitor Thread")

    return tid
  end

  def drain_queue
    while @queue.length > 0
      @queue.deq.to_miq_a.each { |event| process_event(event) }
    end
  end

  def process_events(events)
    events.to_miq_a.each do |event|
      heartbeat
      process_event(event)
      Thread.pass
    end
  end

  def do_work
    if @tid.nil? || !@tid.alive?
      $log.info("#{self.log_prefix} Event Monitor Thread gone. Restarting...")
      @tid = start_event_monitor
    end

    process_events(@queue.deq) while @queue.length > 0
  end
end
