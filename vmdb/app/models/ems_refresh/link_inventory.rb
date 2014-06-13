module EmsRefresh::LinkInventory
  # Link EMS inventory through the relationships table
  def link_ems_inventory(ems, target, prev_relats, new_relats)
    log_header = "MIQ(#{self.name}.link_ems_inventory) EMS: [#{ems.name}], id: [#{ems.id}]"
    $log.info "#{log_header} Linking EMS Inventory..."
    $log.debug "#{log_header} prev_relats: #{prev_relats.inspect}"
    $log.debug "#{log_header} new_relats:  #{new_relats.inspect}"

    if prev_relats == new_relats
      $log.info "#{log_header} Linking EMS Inventory...Complete"
      return
    end

    # Hook up a relationship from the EMS to the root folder
    $log.info "#{log_header} Updating EMS root folder relationship."
    root_id = new_relats[:ext_management_systems_to_folders][ems.id][0]
    if root_id.nil?
      ems.remove_all_children
    else
      ems.replace_children(EmsFolder.find_by_id(root_id))
    end

    # Do the Folders to *, and Clusters to * relationships
    #   For these, we only disconnect when doing an EMS refresh since we don't have
    #   enough information in the filtered data for other refresh types
    do_disconnect = target.kind_of?(ExtManagementSystem)

    # Do the Folders to Folders relationships
    self.update_relats(:folders_to_folders, prev_relats, new_relats) do |f|
      folder = EmsFolder.find_by_id(f)
      break if folder.nil?
      [ do_disconnect ? Proc.new { |f2| folder.remove_folder(EmsFolder.find_by_id(f2)) } : nil, # Disconnect proc
        Proc.new { |f2| folder.add_folder(EmsFolder.find_by_id(f2)) } ]                         # Connect proc
    end

    # Do the Folders to Clusters relationships
    self.update_relats(:folders_to_clusters, prev_relats, new_relats) do |f|
      folder = EmsFolder.find_by_id(f)
      break if folder.nil?
      [ do_disconnect ? Proc.new { |c| folder.remove_cluster(EmsCluster.find_by_id(c)) } : nil, # Disconnect proc
        Proc.new { |c| folder.add_cluster(EmsCluster.find_by_id(c)) } ]                         # Connect proc
    end

    # Do the Folders to Hosts relationships
    self.update_relats(:folders_to_hosts, prev_relats, new_relats) do |f|
      folder = EmsFolder.find_by_id(f)
      break if folder.nil?
      [ do_disconnect ? Proc.new { |h| folder.remove_host(Host.find_by_id(h)) } : nil,             # Disconnect proc
        Proc.new { |h| host = Host.find_by_id(h); host.replace_parent(folder) unless host.nil? } ] # Connect proc
    end

    # Do the Folders to Vms relationships
    self.update_relats(:folders_to_vms, prev_relats, new_relats) do |f|
      folder = EmsFolder.find_by_id(f)
      break if folder.nil?
      [ do_disconnect ? Proc.new { |v| folder.remove_vm(VmOrTemplate.find_by_id(v)) } : nil, # Disconnect proc
        Proc.new { |v| folder.add_vm(VmOrTemplate.find_by_id(v)) } ]                         # Connect proc
    end

    # Do the Clusters to ResourcePools relationships
    self.update_relats(:clusters_to_resource_pools, prev_relats, new_relats) do |c|
      cluster = EmsCluster.find_by_id(c)
      break if cluster.nil?
      [ do_disconnect ? Proc.new { |r| cluster.remove_resource_pool(ResourcePool.find_by_id(r)) } : nil, # Disconnect proc
        Proc.new { |r| cluster.add_resource_pool(ResourcePool.find_by_id(r)) } ]                         # Connect proc
    end

    # Do the Hosts to * relationships, ResourcePool to * relationships
    #   For these, we only disconnect when doing an EMS or Host refresh since we don't
    #   have enough information in the filtered data for other refresh types
    do_disconnect ||= target.kind_of?(Host)

    # Do the Hosts to ResourcePools relationships
    self.update_relats(:hosts_to_resource_pools, prev_relats, new_relats) do |h|
      host = Host.find_by_id(h)
      break if host.nil?
      [ do_disconnect ? Proc.new { |r| rp = ResourcePool.find_by_id(r); rp.remove_parent(host) unless rp.nil? } : nil, # Disconnect proc
        Proc.new { |r| rp = ResourcePool.find_by_id(r); rp.set_parent(host) unless rp.nil? } ]                         # Connect proc
    end

    # Do the ResourcePools to ResourcePools relationships
    self.update_relats(:resource_pools_to_resource_pools, prev_relats, new_relats) do |r|
      rp = ResourcePool.find_by_id(r)
      break if rp.nil?
      [ do_disconnect ? Proc.new { |r2| rp.remove_resource_pool(ResourcePool.find_by_id(r2)) } : nil, # Disconnect proc
        Proc.new { |r2| rp.add_resource_pool(ResourcePool.find_by_id(r2)) } ]                         # Connect proc
    end

    # Do the VMs to * relationships
    #   We do disconnects for all refresh types since we have enough
    #   information in the filtered data for all refresh types

    # Do the ResourcePools to VMs relationships
    self.update_relats(:resource_pools_to_vms, prev_relats, new_relats) do |r|
      rp = ResourcePool.find_by_id(r)
      break if rp.nil?
      [ Proc.new { |v| rp.remove_vm(VmOrTemplate.find_by_id(v)) }, # Disconnect proc
        Proc.new { |v| rp.add_vm(VmOrTemplate.find_by_id(v)) } ]   # Connect proc
    end

    $log.info "#{log_header} Linking EMS Inventory...Complete"
  end

  # Link HABTM relationships for the object, via the accessor, for the records
  #   specified by the hashes.
  def link_habtm(object, hashes, accessor, model, do_disconnect = true)
    return unless object.respond_to?(accessor)

    prev_ids = object.send(accessor).collect(&:id)
    new_ids  = hashes.collect { |s| s[:id] }.compact unless hashes.nil?
    self.update_relats_by_ids(prev_ids, new_ids,
      do_disconnect ? Proc.new { |s| object.send(accessor).delete(model.find_by_id(s)) } : nil, # Disconnect proc
      Proc.new { |s| object.send(accessor) << model.find_by_id(s) }                             # Connect proc
    )
  end

  #
  # Helper methods for EMS metadata linking
  #

  def update_relats(type, prev_relats, new_relats)
    log_header = "MIQ(#{self.name}.update_relats)"
    $log.info "#{log_header} Updating #{type.to_s.titleize} relationships."

    if new_relats[type].kind_of?(Array) || prev_relats[type].kind_of?(Array)
      # Case where we have a single set of ids
      disconnect_proc, connect_proc = yield
      self.update_relats_by_ids(prev_relats[type], new_relats[type], disconnect_proc, connect_proc)
    else
      # Case where we have multiple sets of ids
      (prev_relats[type].keys | new_relats[type].keys).each do |k|
        disconnect_proc, connect_proc = yield(k)
        self.update_relats_by_ids(prev_relats[type][k], new_relats[type][k], disconnect_proc, connect_proc)
      end
    end
  end

  def update_relats_by_ids(prev_ids, new_ids, disconnect_proc, connect_proc)
    log_header = "MIQ(#{self.name}.update_relats_by_ids)"

    common = prev_ids & new_ids unless prev_ids.nil? || new_ids.nil?
    unless common.nil?
      prev_ids -= common
      new_ids -= common
    end

    unless prev_ids.nil? || disconnect_proc.nil?
      prev_ids.each do |p|
        begin
          disconnect_proc.call(p)
        rescue => err
          $log.error "#{log_header} An error occurred while disconnecting id [#{p}]: #{err}"
          $log.log_backtrace(err)
        end
      end
    end

    unless new_ids.nil? || connect_proc.nil?
      new_ids.each do |n|
        begin
          connect_proc.call(n)
        rescue => err
          $log.error "#{log_header} An error occurred while connecting id [#{n}]: #{err}"
          $log.log_backtrace(err)
        end
      end
    end
  end
end
