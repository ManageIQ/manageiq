module VmOrTemplate::Operations::Relocation
  def raw_migrate(host, pool = nil, priority = "defaultPriority", state = nil)
    raise "VM has no EMS, unable to migrate VM" unless self.ext_management_system
    raise "Host not specified, unable to migrate VM" unless host.kind_of?(Host)

    if pool.nil?
      pool = host.default_resource_pool || (host.ems_cluster && host.ems_cluster.default_resource_pool)
      raise "Default Resource Pool for Host <#{host.name}> not found, unable to migrate VM" unless pool.kind_of?(ResourcePool)
    else
      raise "Specified Resource Pool <#{pool.inspect}> for Host <#{host.name}> is invalid, unable to migrate VM" unless pool.kind_of?(ResourcePool)
    end

    host_mor = host.ems_ref_obj
    pool_mor = pool.ems_ref_obj
    run_command_via_parent(:vm_migrate, :host => host_mor, :pool => pool_mor, :priority => priority, :state => state)
  end

  def migrate(host, pool = nil, priority = "defaultPriority", state = nil)
    raw_migrate(host, pool, priority, state)
  end

  def raw_relocate(host, pool=nil, datastore=nil, disk_move_type=nil, transform=nil, priority="defaultPriority", disk=nil)
    raise "VM has no EMS, unable to relocate VM" unless self.ext_management_system
    raise "Unable to relocate VM: Specified Host is not a valid object" if host && !host.kind_of?(Host)
    raise "Unable to relocate VM: Specified Resource Pool is not a valid object" if pool && !pool.kind_of?(ResourcePool)
    raise "Unable to relocate VM: Specified Datastore is not a valid object" if datastore && !datastore.kind_of?(Storage)

    if pool.nil?
      if host
        pool = host.default_resource_pool || (host.ems_cluster && host.ems_cluster.default_resource_pool)
        raise "Default Resource Pool for Host <#{host.name}> not found, unable to migrate VM" unless pool.kind_of?(ResourcePool)
      end
    else
      raise "Specified Resource Pool <#{pool.inspect}> for Host <#{host.name}> is invalid, unable to migrate VM" unless pool.kind_of?(ResourcePool)
    end

    host_mor      = host.ems_ref_obj if host
    pool_mor      = pool.ems_ref_obj if pool
    datastore_mor = datastore.ems_ref_obj if datastore

    run_command_via_parent(:vm_relocate, :host => host_mor, :pool => pool_mor, :datastore => datastore_mor, :disk_move_type => disk_move_type, :transform => transform, :priority => priority, :disk => disk)
  end

  def relocate(host, pool=nil, datastore=nil, disk_move_type=nil, transform=nil, priority="defaultPriority", disk=nil)
    raw_relocate(host, pool, datastore, disk_move_type, transform, priority, disk)
  end

  def migrate_via_ids(host_id, pool_id = nil, priority = "defaultPriority", state = nil)
    host = Host.find_by_id(host_id)
    raise "Host with ID=#{host_id} was not found" if host.nil?
    pool = pool_id.nil? ? nil : ResourcePool.find_by_id(pool_id)
    migrate(host, pool, priority, state)
  end
end
