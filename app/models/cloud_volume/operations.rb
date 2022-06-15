module CloudVolume::Operations
  extend ActiveSupport::Concern

  # Attach a cloud volume as a queued task and return the task id. The queue
  # name and the queue zone are derived from the server EMS, and both a userid
  # and server EMS ref are mandatory. The device is optional.
  #
  def attach_volume_queue(userid, server_ems_ref, device = nil)
    task_opts = {
      :action => "attaching Cloud Volume for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'attach_volume',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [server_ems_ref, device]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def attach_volume(server_ems_ref, device = nil)
    raw_attach_volume(server_ems_ref, device)
  end

  def clone_volume_queue(userid, options = {})
    task_opts = {
      :action => "cloning Cloud Volume for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'clone_volume',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def clone_volume(options = {})
    raw_clone_volume(options)
  end

  # Detach a cloud volume as a queued task and return the task id. The queue
  # name and the queue zone are derived from the server EMS, and both a userid
  # and server EMS ref are mandatory.
  #
  def detach_volume_queue(userid, server_ems_ref)
    task_opts = {
      :action => "detaching Cloud Volume for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'detach_volume',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [server_ems_ref]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def detach_volume(server_ems_ref)
    raw_detach_volume(server_ems_ref)
  end
end
