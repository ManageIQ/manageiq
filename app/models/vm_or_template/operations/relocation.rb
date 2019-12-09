module VmOrTemplate::Operations::Relocation
  def raw_live_migrate(_options = nil)
    raise NotImplementedError, _("raw_live_migrate must be implemented in a subclass")
  end

  def live_migrate(options = {})
    raw_live_migrate(options)
  end

  def raw_evacuate(_options = nil)
    raise NotImplementedError, _("raw_evacuate must be implemented in a subclass")
  end

  # Evacuate a VM (i.e. move to another host) as a queued task and return the
  # task id. The queue name and the queue zone are derived from the EMS, and
  # both the userid and options are mandatory.
  #
  def evacuate_queue(userid, options)
    task_opts = {
      :action => "evacuating VM for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'evacuate',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => queue_name_for_ems_operations,
      :zone        => my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def evacuate(options = {})
    raw_evacuate(options)
  end

  def raw_migrate(host, pool = nil, priority = "defaultPriority", state = nil)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def migrate(host, pool = nil, priority = "defaultPriority", state = nil)
    raise _("VM has no EMS, unable to migrate VM") unless ext_management_system

    raw_migrate(host, pool, priority, state)
  end

  def raw_relocate(host, pool = nil, datastore = nil, disk_move_type = nil, transform = nil, priority = "defaultPriority", disk = nil)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def relocate(host, pool = nil, datastore = nil, disk_move_type = nil, transform = nil, priority = "defaultPriority", disk = nil)
    raise _("VM has no EMS, unable to relocate VM") unless ext_management_system

    raw_relocate(host, pool, datastore, disk_move_type, transform, priority, disk)
  end

  def raw_move_into_folder(folder)
    raise NotImplementedError, _("must be implemented in a subclass")
  end

  def move_into_folder(folder_or_id)
    raise _("VM has no EMS, unable to move VM into a new folder") unless ext_management_system
    folder = folder_or_id.kind_of?(Integer) ? EmsFolder.find(folder_or_id) : folder_or_id

    if parent_blue_folder == folder
      raise _("The VM '%{name}' is already running on the same folder as the destination.") % {:name => name}
    end

    raw_move_into_folder(folder)
  end

  def move_into_folder_queue(userid, folder)
    task_opts = {
      :action => "moving Vm to Folder #{folder.name} for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'move_into_folder',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [folder.id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def migrate_via_ids(host_id, pool_id = nil, priority = "defaultPriority", state = nil)
    host = Host.find_by(:id => host_id)
    raise _("Host with ID=%{host_id} was not found") % {:host_id => host_id} if host.nil?
    pool = pool_id && ResourcePool.find_by(:id => pool_id)
    migrate(host, pool, priority, state)
  end
end
