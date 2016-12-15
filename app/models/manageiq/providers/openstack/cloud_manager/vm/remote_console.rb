class ManageIQ::Providers::Openstack::CloudManager::Vm
  module RemoteConsole
    def console_supported?(type)
      %w(SPICE VNC).include?(type.upcase)
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

    def remote_console_acquire_ticket(_userid, _originating_server, _console_type)
      url = ext_management_system.with_provider_connection({:service => "Compute", :tenant_name => cloud_tenant.name}) do |con|
        response = con.get_vnc_console(ems_ref, 'novnc')
        return nil if response.body.fetch_path('console', 'type') != 'novnc'
        response.body.fetch_path('console', 'url')
      end
      {:remote_url => url, :proto => 'remote'}
    end

    def remote_console_acquire_ticket_queue(protocol, userid)
      task_opts = {
        :action => "acquiring Instance #{name} #{protocol.to_s.upcase} remote console ticket for user #{userid}",
        :userid => userid
      }

      queue_opts = {
        :class_name  => self.class.name,
        :instance_id => id,
        :method_name => 'remote_console_acquire_ticket',
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => 'ems_operations',
        :zone        => my_zone,
        :args        => [userid, protocol]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end
end
