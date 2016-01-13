class ManageIQ::Providers::Azure::CloudManager::EventCatcher::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner
  include ManageIQ::Providers::Azure::EventCatcherMixin

  def event_monitor_handle
    unless @event_monitor_handle
      client_id             = @ems.authentication_userid
      client_key            = @ems.authentication_password
      tenant_id             = @ems.azure_tenant_id
      azure_region          = @ems.provider_region
      @event_monitor_handle = ManageIQ::Providers::Azure::CloudManager::EventCatcher::Stream.new(
        client_id, client_key, azure_region, tenant_id)
    end
    @event_monitor_handle
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
      if events && !events.empty?
        _log.debug("#{log_prefix} Received events #{events.collect { |e| parse_event_type(e) }}")
        @queue.enq events
      end
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
  end

  def process_event(event)
    if filtered?(event)
      _log.info "#{log_prefix} Skipping filtered Azure event #{parse_event_type(event)} for #{event["resourceId"]}"
    else
      _log.info "#{log_prefix} Caught event #{parse_event_type(event)} for #{event["resourceId"]}"
      EmsEvent.add_queue('add_azure', @cfg[:ems_id], event)

    end
  end

  def filtered?(event)
    # We do not care for 'Begin' events, only the 'End' events which indicate
    # the action the event relates to was completed successfully.
    event_type = parse_event_type(event)
    filtered_events.include?(event_type) || event_type.end_with?("BeginRequest")
  end
end
