class ManageIQ::Providers::Redhat::InfraManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  def event_monitor_handle
    require 'ovirt_provider/events/ovirt_event_monitor'
    @event_monitor_handle ||= OvirtEventMonitor.new(event_monitor_options)
  end

  def event_monitor_options
    {
      :server     => @ems.hostname,
      :port       => @ems.port.blank? ? nil : @ems.port.to_i,
      :username   => @ems.authentication_userid,
      :password   => @ems.authentication_password,
      :verify_ssl => false
    }
  end

  def reset_event_monitor_handle
    @event_monitor_handle = nil
  end

  def stop_event_monitor
    begin
      @event_monitor_handle.stop unless @event_monitor_handle.nil?
    rescue Exception => err
      _log.warn("#{self.log_prefix} Event Monitor Stop errored because [#{err.message}]")
      _log.warn("#{self.log_prefix} Error details: [#{err.details}]")
      _log.log_backtrace(err)
    ensure
      reset_event_monitor_handle
    end
  end

  def monitor_events
    begin
      event_monitor_handle.start
      event_monitor_handle.each_batch do |events|
        @queue.enq events
        sleep_poll_normal
      end
    ensure
      reset_event_monitor_handle
    end
  end

  def process_event(event)
    if self.filtered_events.include?(event[:name])
      _log.info "#{self.log_prefix} Skipping caught event [#{event[:name]}]"
    else
      _log.info "#{self.log_prefix} Caught event [#{event[:name]}]"
      EmsEvent.add_queue('add_rhevm', @cfg[:ems_id], event.to_hash)
    end
  end
end
