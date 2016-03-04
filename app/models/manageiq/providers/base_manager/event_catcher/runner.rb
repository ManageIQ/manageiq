require 'thread'
require 'concurrent/atomic/event'

class ManageIQ::Providers::BaseManager::EventCatcher::Runner < ::MiqWorker::Runner
  class EventCatcherHandledException < StandardError
  end

  self.wait_for_worker_monitor = false

  OPTIONS_PARSER_SETTINGS = ::MiqWorker::Runner::OPTIONS_PARSER_SETTINGS + [
    [:ems_id, 'EMS Instance ID', String],
  ]

  def after_initialize
    @ems = ExtManagementSystem.find(@cfg[:ems_id])
    do_exit("Unable to find instance for EMS ID [#{@cfg[:ems_id]}].", 1) if @ems.nil?
    do_exit("EMS ID [#{@cfg[:ems_id]}] failed authentication check.", 1) unless @ems.authentication_check.first

    @filtered_events = @ems.blacklisted_event_names
    _log.info "#{log_prefix} Event Catcher skipping the following events:"
    $log.log_hashes(@filtered_events)

    # Global Work Queue
    @queue = Queue.new
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

  # the monitor runs in it's own thread and only yields raw events to put them into an internal queue
  # this queue is read from another thread which parses the events and queues them for writing
  # @yield [event_or_events] any object or array of objects to be parsed by parse_event
  def monitor_events
    raise NotImplementedError, _("must be implemented in subclass")
  end

  def process_event(_event)
    raise NotImplementedError, _("must be implemented in subclass")
  end

  # runs in its own thread and get called for every object yielded by monitor_events
  # if monitor_events yields an array this is called for every object in the array
  #
  # @param [Object] _event the event object
  # @return [Hash, nil] an event_hash to be read by EmsEvent.add or nil if the event should be ignored
  def parse_event(_event)
    raise NotImplementedError, "must be implemented in subclass"
  end

  def process_event(event)
    event_hash = parse_event(event)
    event_hash[:ems_id] ||= @cfg[:ems_id]
    # FIXME: maybe check for correctness of event
    EmsEvent.add_queue('add', @cfg[:ems_id], event_hash) if event_hash
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
        monitor_events do |event_or_events|
          @queue.enq event_or_events
        end
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
