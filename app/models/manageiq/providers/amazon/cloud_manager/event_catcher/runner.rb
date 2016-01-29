class ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  def stop_event_monitor
    @event_monitor_handle.try!(:stop)
  ensure
    reset_event_monitor_handle
  end

  def monitor_events
    event_monitor_handle.start
    event_monitor_handle.each_batch do |events|
      _log.debug { "#{log_prefix} Received events #{events.collect(&:message)}" }
      event_monitor_running
      @queue.enq events
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
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
