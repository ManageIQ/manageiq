module EventCatcherOpenstackMixin
  # seems like most of this class could be boilerplate when compared against EventCatcherRhevm
  def event_monitor_handle
    require 'openstack/openstack_event_monitor'
    unless @event_monitor_handle
      options = {}
      options[:hostname] = @ems.hostname
      options[:port]     = self.worker_settings[:amqp_port]
      if @ems.has_authentication_type? :amqp
        options[:username] = @ems.authentication_userid(:amqp)
        options[:password] = @ems.authentication_password(:amqp)
      end
      options[:topics]   = self.worker_settings[:topics]
      options[:duration] = self.worker_settings[:duration]
      options[:capacity] = self.worker_settings[:capacity]

      options[:client_ip] = MiqServer.my_server.ipaddress
      @event_monitor_handle = OpenstackEventMonitor.new(options)
    end
    @event_monitor_handle
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
        $log.debug("#{self.log_prefix} Received events #{events.collect { |e| e.payload["event_type"] }}") if $log.debug?
        @queue.enq events
        sleep_poll_normal
      end
    ensure
      reset_event_monitor_handle
    end
  end

  def process_event(event)
    if self.filtered_events.include?(event.payload[:event_type])
      $log.info "#{self.log_prefix} Skipping caught event [#{event.payload["event_type"]}]"
    else
      $log.info "#{self.log_prefix} Caught event [#{event.payload["event_type"]}]"

      event_hash = {}
      # copy content
      content = event.payload
      event_hash[:content] = content.reject { |k, _v| k.start_with? "_context_" }

      # copy context
      event_hash[:context] = {}
      content.select { |k, _v| k.start_with? "_context_" }.each_pair do |k, v|
        event_hash[:context][k] = v
      end

      # copy attributes
      event_hash[:user_id]      = event.metadata[:user_id]
      event_hash[:priority]     = event.metadata[:priority]
      event_hash[:content_type] = event.metadata[:content_type]
      add_openstack_queue(event_hash)
    end
  end
end
