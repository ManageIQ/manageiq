class ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  def stop_event_monitor
    @event_monitor_handle.try!(:stop)
  ensure
    reset_event_monitor_handle
  end

  def monitor_events
    event_monitor_handle.poll do |event|
      _log.debug { "#{log_prefix} Received event #{event["messageId"]}" }
      event_monitor_running
      @queue.enq event
    end
  ensure
    stop_event_monitor
  end

  def process_event(event)
    if filtered?(event)
      _log.info "#{log_prefix} Skipping filtered Amazon event [#{event["messageId"]}]"
    else
      _log.info "#{log_prefix} Caught event [#{event["messageId"]}]"
      EmsEvent.add_queue('add_amazon', @cfg[:ems_id], event)
    end
  end

  private

  def filtered?(event)
    filtered_events.include?(event["messageType"])
  end

  def event_monitor_handle
    @event_monitor_handle ||= ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream.new(@ems)
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end
end
