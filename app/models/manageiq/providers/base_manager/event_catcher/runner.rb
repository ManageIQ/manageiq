require 'thread'
require 'concurrent/atomic/event'
require 'util/duplicate_blocker'

class ManageIQ::Providers::BaseManager::EventCatcher::Runner < ::MiqWorker::Runner
  class EventCatcherHandledException < StandardError
  end

  include DuplicateBlocker

  def after_initialize
    @ems = ExtManagementSystem.find(@cfg[:ems_id])
    do_exit("Unable to find instance for EMS ID [#{@cfg[:ems_id]}].", 1) if @ems.nil?
    do_exit("EMS ID [#{@cfg[:ems_id]}] failed authentication check.", 1) unless @ems.authentication_check.first

    @filtered_events = @ems.blacklisted_event_names
    _log.info("#{log_prefix} Event Catcher skipping the following events:\n#{@filtered_events.to_a.join("\n")}")

    configure_event_flooding_prevention if worker_settings.try(:[], :flooding_monitor_enabled)

    # Global Work Queue
    @queue = Queue.new
  end

  def configure_event_flooding_prevention
    flood_handler = self.class.dedup_handler

    flood_handler.duplicate_window    = 1.minute
    flood_handler.window_slot_width   = 6.seconds
    flood_handler.progress_threshold  = 100
    flood_handler.duplicate_threshold = worker_settings[:flooding_events_per_minute]
    flood_handler.throw_exception_when_blocked = false

    flood_handler.logger = _log
    flood_handler.descriptor    = ->(_meth, *args) { event_dedup_descriptor(args[0]) }
    flood_handler.key_generator = ->(_meth, *args) { event_dedup_key(args[0]) }

    self.class.dedup_instance_method(:queue_event)

    _log.info("Event flood_handler settings:")
    _log.info("  duplicate_window #{flood_handler.duplicate_window}")
    _log.info("  duplicate_threshold #{flood_handler.duplicate_threshold}")
    _log.info("  window_slot_width #{flood_handler.window_slot_width}")
    _log.info("  progress_threshold #{flood_handler.progress_threshold}")
  end

  # Extract a key to represent an event. Events with the same key are considered duplicates and
  # might be subjected to be blocked to prevent flooding
  def event_dedup_key(_event)
    raise NotImplementedError, _("must be implemented in subclass")
  end

  # A string representation for an event. This is used for logging the blocked events
  def event_dedup_descriptor(_event)
    raise NotImplementedError, _("must be implemented in subclass")
  end

  def do_before_work_loop
    @tid = start_event_monitor
  end

  def log_prefix
    @log_prefix ||= "EMS [#{@ems.hostname}] as [#{@ems.authentication_userid}]"
  end

  def before_exit(message, _exit_code)
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
      @tid.join(worker_settings[:ems_event_thread_shutdown_timeout]) rescue nil
    end

    #
    # Drain the Queue of the Event Monitor
    #
    if @queue
      safe_log("#{message} Draining Event Queue.")
      drain_queue rescue nil
    end
  end

  attr_reader :filtered_events

  # Called when there is any change in BlacklistedEvent
  def sync_blacklisted_events
    return unless @ems
    filters = @ems.blacklisted_event_names

    if @filtered_events.nil? || @filtered_events != filters
      adds    = filters - @filtered_events
      deletes = @filtered_events - filters

      @filtered_events = filters
      _log.info("Synchronizing blacklisted events: #{filters}")
      _log.info("   Blacklisted events added: #{adds}")
      _log.info("   Blacklisted events deleted: #{deletes}")
    end
  end

  def stop_event_monitor
    raise NotImplementedError, _("must be implemented in subclass")
  end

  def monitor_events
    raise NotImplementedError, _("must be implemented in subclass")
  end

  # This method has been refactored to go through two steps, namely filtered? and queue_event.
  # Therefore every subclass should override filtered? and queue_event
  #
  # For historical reason existing providers still directly implement process_event
  # They should be eventually refactored following the example of VMWare provider.
  def process_event(event)
    queue_event(event) unless filtered?(event)
  end

  def queue_event(_event)
    raise NotImplementedError, _("must be implemented in subclass")
  end

  # default implementation: none event is skipped
  def filtered?(_event)
    false
  end

  def event_monitor_running
    @monitor_started.set
  end

  def start_event_monitor
    @log_prefix = nil
    @exit_requested = false
    @monitor_started = Concurrent::Event.new

    begin
      _log.info("#{log_prefix} Validating Connection/Credentials")
      @ems.verify_credentials
    rescue => err
      _log.warn("#{log_prefix} #{err.message}")
      return nil
    end

    _log.info("#{log_prefix} Starting Event Monitor Thread")

    tid = Thread.new do
      begin
        monitor_events
      rescue EventCatcherHandledException
        Thread.exit
      rescue TemporaryFailure
        raise
      rescue => err
        _log.error("#{log_prefix} Event Monitor Thread aborted because [#{err.message}]")
        _log.log_backtrace(err) unless err.kind_of?(Errno::ECONNREFUSED)
        Thread.exit
      ensure
        @monitor_started.set
      end
    end

    @monitor_started.wait
    _log.info("#{log_prefix} Started Event Monitor Thread")

    tid
  end

  def drain_queue
    while @queue.length > 0
      Array.wrap(@queue.deq).each { |event| process_event(event) }
    end
  end

  def process_events(events)
    Array.wrap(events).each do |event|
      heartbeat
      process_event(event)
      Thread.pass
    end
  end

  def do_work
    if @tid.nil? || !@tid.alive?
      if !@tid.nil? && @tid.status.nil?
        dead_tid, @tid = @tid, nil
        _log.info("#{log_prefix} Waiting for the Monitor Thread to exit...")
        dead_tid.join # raise the exception the dead thread failed with
      end

      _log.info("#{log_prefix} Event Monitor Thread gone. Restarting...")
      @tid = start_event_monitor
    end

    process_events(@queue.deq) while @queue.length > 0
  end
end
