require 'workers/event_catcher'

class EventCatcherVmware < EventCatcher
  def event_monitor_handle
    require 'VMwareWebService/MiqVimEventMonitor'
    @event_monitor_handle ||= MiqVimEventMonitor.new(
                                @ems.ipaddress,
                                @ems.authentication_userid,
                                @ems.authentication_password,
                                nil,
                                self.worker_settings[:ems_event_page_size])
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end

  def stop_event_monitor
    begin
      @event_monitor_handle.stop unless @event_monitor_handle.nil?
    rescue Exception => err
      $log.warn("#{self.log_prefix} Event Monitor Stop errored because [#{err.message}]")
      $log.warn("#{self.log_prefix} Error details: [#{err.details}]")
      $log.log_backtrace(err)
    ensure
      reset_event_monitor_handle
    end
  end

  def monitor_events
    begin
      event_monitor_handle.monitorEvents do |ea|
        @queue.enq(ea)
        sleep_poll_normal
      end
    rescue Handsoap::Fault => err
      if ( @exit_requested && (err.code == "ServerFaultCode") && (err.reason == "The task was canceled by a user.") )
        $log.info("#{self.log_prefix} Event Monitor Thread terminated normally")
      else
        $log.error("#{self.log_prefix} Event Monitor Thread aborted because [#{err.message}]")
        $log.error("#{self.log_prefix} Error details: [#{err.details}]")
        $log.log_backtrace(err)
      end
      raise EventCatcherHandledException
    ensure
      reset_event_monitor_handle
    end
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

    if self.filtered_events.include?(event_type) || self.filtered_events.include?(sub_event_type)
      $log.info "#{self.log_prefix} Skipping caught event [#{display_name}] chainId [#{event['chainId']}]"
    else
      $log.info "#{self.log_prefix} Queueing event [#{display_name}] chainId [#{event['chainId']}]"
      EmsEvent.add_queue('add_vc', @cfg[:ems_id], event)
    end
  end
end
