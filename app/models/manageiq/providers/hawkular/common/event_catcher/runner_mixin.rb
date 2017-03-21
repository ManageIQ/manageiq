module ManageIQ::Providers::Hawkular::Common::EventCatcher::RunnerMixin
  extend ActiveSupport::Concern

  def log_handle
    self.class.log_handle
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end

  def stop_event_monitor
    @event_monitor_handle.try(:stop)
  ensure
    reset_event_monitor_handle
  end

  def monitor_events
    event_monitor_handle.start
    event_monitor_handle.each_batch do |events|
      event_monitor_running
      new_events = events.select { |e| whitelisted?(e) }
      log_handle.debug("#{log_prefix} Discarding events #{events - new_events}") if new_events.length < events.length
      if new_events.any?
        log_handle.debug "#{log_prefix} Queueing events #{new_events}"
        @queue.enq new_events
      end
      # invoke the configured sleep before the next event fetch
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
  end

  def event_monitor_handle
    @event_monitor_handle ||= self.class.event_monitor_class.new(@ems)
  end

  def process_event(event)
    log_handle.debug "Processing Event #{event}"
    event_hash = event_to_hash(event, @cfg[:ems_id])

    if blacklisted?(event_hash[:event_type])
      log_handle.debug "#{log_prefix} Filtering blacklisted event [#{event}]"
    else
      log_handle.debug "#{log_prefix} Adding ems event [#{event_hash}]"
      EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
    end
  end

  def blacklisted?(event_type)
    filtered_events.include?(event_type)
  end
end
