class ManageIQ::Providers::Vmware::InfraManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  def event_monitor_handle
    require 'VMwareWebService/MiqVimEventMonitor'
    @event_monitor_handle ||= MiqVimEventMonitor.new(
      @ems.hostname,
      @ems.authentication_userid,
      @ems.authentication_password,
      nil,
      worker_settings[:ems_event_page_size],
      worker_settings[:ems_event_max_wait])
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end

  def stop_event_monitor
    @event_monitor_handle.stop unless @event_monitor_handle.nil?
  rescue Exception => err
    _log.warn("#{log_prefix} Event Monitor Stop errored because [#{err.message}]")
    _log.warn("#{log_prefix} Error details: [#{err.details}]")
    _log.log_backtrace(err)
  ensure
    reset_event_monitor_handle
  end

  def monitor_events
    event_monitor_running
    event_monitor_handle.monitorEvents do |ea|
      @queue.enq(ea)
      sleep_poll_normal
    end
  rescue Handsoap::Fault => err
    if  @exit_requested && (err.code == "ServerFaultCode") && (err.reason == "The task was canceled by a user.")
      _log.info("#{log_prefix} Event Monitor Thread terminated normally")
    else
      _log.error("#{log_prefix} Event Monitor Thread aborted because [#{err.message}]")
      _log.error("#{log_prefix} Error details: [#{err.details}]")
      _log.log_backtrace(err)
    end
    raise EventCatcherHandledException
  ensure
    reset_event_monitor_handle
  end

  def process_event(event)
    event_type = event['eventType']
    return if event_type.nil?

    case event_type
    when "TaskEvent"
      sub_event_type = event.fetch_path('info', 'name')
      display_name   = "#{event_type}]-[#{sub_event_type}"
    when "EventEx"
      sub_event_type = event['eventTypeId']
      display_name   = "#{event_type}]-[#{sub_event_type}"
    else
      sub_event_type = nil
      display_name   = event_type
    end

    if filtered_events.include?(event_type) || filtered_events.include?(sub_event_type)
      _log.info "#{log_prefix} Skipping caught event [#{display_name}] chainId [#{event['chainId']}]"
    else
      _log.info "#{log_prefix} Queueing event [#{display_name}] chainId [#{event['chainId']}]"
      EmsEvent.add_queue('add_vc', @cfg[:ems_id], event)
    end
  end
end
