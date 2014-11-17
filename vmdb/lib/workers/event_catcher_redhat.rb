require 'workers/event_catcher'

class EventCatcherRedhat < EventCatcher
  def event_monitor_handle
    require 'ovirt'
    @event_monitor_handle ||= Ovirt::EventMonitor.new(
      :server     => @ems.ipaddress,
      :port       => @ems.port,
      :username   => @ems.authentication_userid,
      :password   => @ems.authentication_password,
      :verify_ssl => false,
    )
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
      $log.info "#{self.log_prefix} Skipping caught event [#{event[:name]}]"
    else
      $log.info "#{self.log_prefix} Caught event [#{event[:name]}]"
      EmsEvent.add_queue('add_rhevm', @cfg[:ems_id], event.to_hash)
    end
  end
end
