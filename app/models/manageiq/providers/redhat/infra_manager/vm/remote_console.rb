class ManageIQ::Providers::Redhat::InfraManager::Vm
  module RemoteConsole
    def console_supported?(type)
      %w(SPICE VNC).include?(type.upcase)
    end

    def remote_display
      provider_object.attributes[:display]
    end

    def validate_remote_console_acquire_ticket(protocol, options = {})
      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} protocol not enabled for this vm") unless protocol.to_sym == :html5

      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} remote console requires the vm to be registered with a management system.") if ext_management_system.nil?

      options[:check_if_running] = true unless options.key?(:check_if_running)
      raise(MiqException::RemoteConsoleNotSupportedError,
            "#{protocol} remote console requires the vm to be running.") if options[:check_if_running] && state != "on"
    end

    def remote_console_acquire_ticket(userid, originating_server, console_type)
      validate_remote_console_acquire_ticket(console_type)

      parsed_ticket = Nokogiri::XML(provider_object.ticket)
      display = provider_object.attributes[:display]

      SystemConsole.force_vm_invalid_token(id)

      console_args = {
        :user       => User.find_by(:userid => userid),
        :vm_id      => id,
        :protocol   => display[:type],
        :secret     => parsed_ticket.xpath('action/ticket/value')[0].text,
        :url_secret => SecureRandom.hex,
        :ssl        => display[:secure_port].present?
      }
      host_address = display[:address]
      host_port    = display[:secure_port] || display[:port]

      SystemConsole.launch_proxy_if_not_local(console_args, originating_server, host_address, host_port)
    end

    def remote_console_acquire_ticket_queue(protocol, userid)
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
        :args        => [userid, MiqServer.my_server.id, protocol]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end
end
