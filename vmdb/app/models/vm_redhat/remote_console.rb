class VmRedhat
  module RemoteConsole
    def console_supported?(type)
      %w(SPICE VNC).include?(type.upcase)
    end

    def remote_display
      provider_object.attributes[:display]
    end

    def validate_remote_console_acquire_ticket(protocol, options = {})
      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} protocol not enabled for this vm") unless protocol == :html5

      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} remote console requires the vm to be registered with a management system.") if ext_management_system.nil?

      options[:check_if_running] = true unless options.key?(:check_if_running)
      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} remote console requires the vm to be running.") if options[:check_if_running] && state != "on"
    end

    def remote_console_acquire_ticket(console_type, _proxy_miq_server = nil)
      validate_remote_console_acquire_ticket(console_type)

      parsed_ticket = Nokogiri::XML(provider_object.ticket)
      display = provider_object.attributes[:display]

      host_address = display[:address]
      host_port    = display[:secure_port] || display[:port]
      ssl          = display[:secure_port].present?
      protocol     = display[:type]

      proxy_address = proxy_port = nil
      password = parsed_ticket.xpath('action/ticket/value')[0].text
      return password, host_address, host_port, proxy_address, proxy_port, protocol, ssl
    end

    def remote_console_acquire_ticket_queue(protocol, userid, proxy_miq_server = nil)
      task_opts = {
        :action => "acquiring Vm #{name} #{protocol.to_s.upcase} remote console ticket for user #{userid}",
        :userid => userid
      }

      queue_opts = {
        :class_name  => self.class.name,
        :instance_id => id,
        :method_name => 'remote_console_acquire_ticket',
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => 'ems_operations',
        :zone        => my_zone,
        :args        => [protocol, proxy_miq_server]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end
end
