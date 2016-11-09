class ManageIQ::Providers::Google::CloudManager::EventCatcher::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner
  include ManageIQ::Providers::Google::EventCatcherMixin

  # Request the event monitor to stop running.
  def stop_event_monitor
    @event_monitor_handle.try(:stop)
  ensure
    reset_event_monitor_handle
  end

  # Start monitoring for events. This method blocks forever until
  # #stop_event_monitor is called.
  def monitor_events
    _log.info "#{log_prefix} Monitoring for events"
    event_monitor_handle.each_batch do |events|
      event_monitor_running
      _log.debug "#{log_prefix} Received events #{events.collect { |e| parse_event_type(e) }}"
      @queue.enq events
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
  end

  def queue_event(event)
    _log.info "#{log_prefix} Caught event #{parse_event_type(event)} for #{parse_resource_id(event)}"
    EmsEvent.add_queue('add_google', @cfg[:ems_id], event)
  end

  private

  def event_monitor_handle
    @event_monitor_handle ||= ManageIQ::Providers::Google::CloudManager::EventCatcher::Stream.new(@ems)
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end

  def filtered?(event)
    event_type = parse_event_type(event)
    filtered_events.include?(event_type)
  end
end
