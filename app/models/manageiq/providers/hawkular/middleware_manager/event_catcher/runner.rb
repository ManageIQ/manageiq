class ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner
  INCLUDE_EVENTS = {'Hawkular Deployment' => '.*'}.freeze

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
      valid_events = events.select { |e| valid?(e) }
      $mw_log.debug("#{log_prefix} Discarding events #{events - valid_events}") if valid_events.length < events.length
      if valid_events.any?
        $mw_log.debug "#{log_prefix} Queueing events #{valid_events}"
        @queue.enq valid_events
      end
      # invoke the configured sleep before the next event fetch
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
  end

  def process_event(event)
    $mw_log.debug "Processing Event #{event}"

    event_data = {
      :timestamp => Time.zone.at(event.ctime / 1000),
      :category  => event.category,
      :message   => event.context['Message'],
      :reason    => event.text,
      :resource  => event.context['CanonicalPath']
    }

    $mw_log.debug "Processing EventData #{event_data}"

    # normalize event type to be valid (no invalid chars) and to easily match any we've made available for automation
    event_type              = "#{event_data[:category]}.#{event_data[:reason]}"
    event_type              = event_type.strip.gsub(/\s+/, "_").downcase
    event_data[:event_type] = event_type

    if filtered?(event_data)
      $mw_log.debug "#{log_prefix} Filtering event [#{event_data}]"
    else
      $mw_log.debug "#{log_prefix} Adding ems event [#{event_data}]"
      event_hash = ManageIQ::Providers::Hawkular::MiddlewareManager::EventParser.event_to_hash(
        event_data, @cfg[:ems_id])
      EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
    end
  end

  private

  def event_monitor_handle
    @event_monitor_handle ||= ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Stream.new(@ems)
  end

  def valid?(event)
    pattern = INCLUDE_EVENTS[event.category]
    message = event.context['Message']
    pattern && message && message.match(pattern)
  end

  # Check for blacklisted event type
  def filtered?(event_data)
    filtered_events.include?(event_data[:event_type])
  end
end
