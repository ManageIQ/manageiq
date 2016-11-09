module ManageIQ::Providers::Openstack::EventCatcherMixin
  # seems like most of this class could be boilerplate when compared against EventCatcherRhevm
  def event_monitor_handle
    require 'openstack/openstack_event_monitor'
    unless @event_monitor_handle
      options = @ems.event_monitor_options
      options[:topics]                        = worker_settings[:topics]
      options[:duration]                      = worker_settings[:duration]
      options[:capacity]                      = worker_settings[:capacity]
      options[:heartbeat]                     = worker_settings[:amqp_heartbeat]
      options[:ceilometer]                    = worker_settings[:ceilometer]
      options[:automatic_recovery]            = true
      options[:recover_from_connection_close] = true
      options[:recovery_attempts]             = worker_settings[:amqp_recovery_attempts]
      options[:ems]                           = @ems

      options[:client_ip] = server.ipaddress
      @event_monitor_handle = OpenstackEventMonitor.new(options)
    end
    @event_monitor_handle
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
    event_monitor_handle.start
    event_monitor_handle.each_batch do |events|
      event_monitor_running
      if events && !events.empty?
        _log.debug("#{log_prefix} Received events #{events.collect { |e| e.payload["event_type"] }}") if _log.debug?
        @queue.enq events
      end
      sleep_poll_normal
    end
  ensure
    reset_event_monitor_handle
  end

  def queue_event(event)
    _log.info "#{log_prefix} Caught event [#{event.payload["event_type"]}]"

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

  def filtered?(event)
    filtered_events.include?(event.payload["event_type"])
  end
end
