module PhysicalServer::Operations
  extend ActiveSupport::Concern

  include Power
  include Led
  include ConfigPattern
  include Lifecycle

  def remote_console_acquire_resource_queue(userid)
    task_opts = {
      :action => "Acquiring remote console file or url from a physical server with uuid #{ems_ref} for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'remote_console_acquire_resource',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [userid, MiqServer.my_server.id]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  private

  def change_state(verb)
    unless ext_management_system
      raise _(" A Server %{server} <%{name}> with Id: <%{id}> is not associated with a provider.") %
            {:server => self, :name => name, :id => id}
    end
    options = {:uuid => ems_ref}
    _log.info("Begin #{verb} server: #{name}  with UUID: #{ems_ref}")
    ext_management_system.send(verb, self, options)
    _log.info("Complete #{verb} #{self}")
  end
end
