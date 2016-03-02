class ManageIQ::Providers::Openstack::CloudManager::Vm
  module RemoteConsole
    def console_supported?(type)
      %w(SPICE VNC).include?(type.upcase)
    end

    def remote_console_acquire_ticket(_console_type)
      url = ext_management_system.with_provider_connection(:service => "Compute") do |con|
        response = con.get_vnc_console(ems_ref, 'novnc')
        return nil if response.body.fetch_path('console', 'type') != 'novnc'
        response.body.fetch_path('console', 'url')
      end
      return nil, url, nil, nil, nil, 'novnc_url', nil
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
        :args        => [protocol, proxy_miq_server]
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end
end
