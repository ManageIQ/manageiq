class ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner

  def initialize(cfg = {})
    super

    # Accept events with an event category in the keyset and whose event message matches the (optional) pattern value
    # - key = event category
    # - value (optional) event message regex
    @whitelist = {
      'Hawkular Deployment' => nil
    }.freeze

    # Some ems events will link to objects in miq inventory. This maps the event category to the object type
    @types = {
      'Hawkular Deployment' => MiddlewareServer.name
    }.freeze
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
      valid_events = events.select { |e| whitelist?(e) }
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

    # determine event type and check blacklist
    event_type = "#{event.category}.#{event.text}"
    event_type = event_type.strip.gsub(/\s+/, "_").downcase

    if blacklist?(event_type)
      $mw_log.debug "#{log_prefix} Filtering blacklisted event [#{event}]"
    else
      event_hash = event_to_hash(event, event_type, @cfg[:ems_id])
      $mw_log.debug "#{log_prefix} Adding ems event [#{event_hash}]"
      EmsEvent.add_queue('add', @cfg[:ems_id], event_hash)
    end
  end

  private

  def event_monitor_handle
    @event_monitor_handle ||= ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Stream.new(@ems)
  end

  def whitelist?(event)
    return false unless @whitelist.key?(event.category)
    pattern = @whitelist[event.category]
    return true unless pattern
    message = event.context['Message']
    message && message.match(pattern)
  end

  def blacklist?(event_type)
    filtered_events.include?(event_type)
  end

  def event_to_hash(event, event_type, ems_id = nil)
    {
      :ems_id          => ems_id,
      :source          => 'HAWKULAR',
      :timestamp       => Time.zone.at(event.ctime / 1000),
      :event_type      => event_type,
      :message         => event.context['Message'],
      :middleware_ref  => event.context['CanonicalPath'],
      :middleware_type => @types[event.category],
      :full_data       => event.to_s
    }
  end
end
