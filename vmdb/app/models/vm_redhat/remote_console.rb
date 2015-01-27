module VmRedhat::RemoteConsole

  def console_supported?(type)
    #type.upcase == remote_display.fetch_path(:type).upcase
    %w(SPICE VNC).include?(type.upcase)
  end

  def remote_display
    # :display=>{:type=>"spice", :address=>"10.16.4.96", :monitors=>1},
    provider_object.attributes[:display]
  end

  def validate_remote_console_acquire_ticket(protocol, options = {})
    #raise(MiqException::RemoteConsoleNotSupportedError, "#{protocol} protocol not enabled for this vm") unless console_supported?(protocol)
    #raise(MiqException::RemoteConsoleNotSupportedError, "#{protocol} protocol not enabled for this vm") unless protocol == :html5

    raise(MiqException::RemoteConsoleNotSupportedError, "#{protocol} remote console requires the vm to be registered with a management system.") if self.ext_management_system.nil?

    options[:check_if_running] = true unless options.has_key?(:check_if_running)
    raise(MiqException::RemoteConsoleNotSupportedError, "#{protocol} remote console requires the vm to be running.") if options[:check_if_running] && self.state != "on"
  end

  def remote_console_acquire_ticket(console_type, proxy_miq_server = nil)
    validate_remote_console_acquire_ticket(console_type)

    display = provider_object.attributes[:display]
    binding.pry
    Rails.logger.debug(display)

    host_address = display[:address]
    host_port    = display[:port]
    protocol     = display[:type]
    #binding.pry

    parsed_ticket = Nokogiri::XML(provider_object.ticket)

    proxy_address = proxy_port = nil
    password = parsed_ticket.xpath('action/ticket/value')[0].text
    return password, host_address, host_port, proxy_address, proxy_port, protocol
  end

  def remote_console_acquire_ticket_queue(protocol, userid, proxy_miq_server = nil)
    task_opts = {
      :action       => "acquiring Vm #{self.name} #{protocol.to_s.upcase} remote console ticket for user #{userid}",
      :userid       => userid
    }

    queue_opts = {
      :class_name   => self.class.name,
      :instance_id  => self.id,
      :method_name  => 'remote_console_acquire_ticket',
      :priority     => MiqQueue::HIGH_PRIORITY,
      :role         => 'ems_operations',
      :zone         => self.my_zone,
      :args         => [protocol, proxy_miq_server]
    }

    return MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end
end
