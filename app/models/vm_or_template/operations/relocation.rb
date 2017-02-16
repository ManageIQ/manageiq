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
      :zone        => my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def evacuate(options = {})
    raw_evacuate(options)
  end

  def raw_migrate(host, pool = nil, priority = "defaultPriority", state = nil)
    raise _("VM has no EMS, unable to migrate VM") unless ext_management_system
    raise _("Host not specified, unable to migrate VM") unless host.kind_of?(Host)

    if pool.nil?
      pool = host.default_resource_pool || (host.ems_cluster && host.ems_cluster.default_resource_pool)
      unless pool.kind_of?(ResourcePool)
        raise _("Default Resource Pool for Host <%{name}> not found, unable to migrate VM") % {:name => host.name}
      end
    else
      unless pool.kind_of?(ResourcePool)
        raise _("Specified Resource Pool <%{pool_name}> for Host <%{name}> is invalid, unable to migrate VM") %
                {:pool_name => pool.inspect, :name => host.name}
      end
    end

    host_mor = host.ems_ref_obj
    pool_mor = pool.ems_ref_obj
    run_command_via_parent(:vm_migrate, :host => host_mor, :pool => pool_mor, :priority => priority, :state => state)
  end

  def migrate(host, pool = nil, priority = "defaultPriority", state = nil)
    raw_migrate(host, pool, priority, state)
  end

  def raw_relocate(host, pool = nil, datastore = nil, disk_move_type = nil, transform = nil, priority = "defaultPriority", disk = nil)
    raise _("VM has no EMS, unable to relocate VM") unless ext_management_system
    raise _("Unable to relocate VM: Specified Host is not a valid object") if host && !host.kind_of?(Host)
    if pool && !pool.kind_of?(ResourcePool)
      raise _("Unable to relocate VM: Specified Resource Pool is not a valid object")
    end
    if datastore && !datastore.kind_of?(Storage)
      raise _("Unable to relocate VM: Specified Datastore is not a valid object")
    end

    if pool.nil?
      if host
        pool = host.default_resource_pool || (host.ems_cluster && host.ems_cluster.default_resource_pool)
        unless pool.kind_of?(ResourcePool)
          raise _("Default Resource Pool for Host <%{name}> not found, unable to migrate VM") % {:name => host.name}
        end
      end
    else
      unless pool.kind_of?(ResourcePool)
        raise _("Specified Resource Pool <%{pool_name}> for Host <%{name}> is invalid, unable to migrate VM") %
                {:pool_name => pool.inspect, :name => host.name}
      end
    end

    host_mor      = host.ems_ref_obj if host
    pool_mor      = pool.ems_ref_obj if pool
    datastore_mor = datastore.ems_ref_obj if datastore

    run_command_via_parent(:vm_relocate, :host => host_mor, :pool => pool_mor, :datastore => datastore_mor, :disk_move_type => disk_move_type, :transform => transform, :priority => priority, :disk => disk)
  end

  def relocate(host, pool = nil, datastore = nil, disk_move_type = nil, transform = nil, priority = "defaultPriority", disk = nil)
    raw_relocate(host, pool, datastore, disk_move_type, transform, priority, disk)
  end

  def migrate_via_ids(host_id, pool_id = nil, priority = "defaultPriority", state = nil)
    host = Host.find_by_id(host_id)
    raise _("Host with ID=%{host_id} was not found") % {:host_id => host_id} if host.nil?
    pool = pool_id.nil? ? nil : ResourcePool.find_by_id(pool_id)
    migrate(host, pool, priority, state)
  end
end
