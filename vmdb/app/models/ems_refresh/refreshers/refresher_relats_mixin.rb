module EmsRefresh::Refreshers::RefresherRelatsMixin
  def find_relats_vmdb(target)
    log_header = "MIQ(RefresherRelatsMixin.find_relats_vmdb) EMS: [#{@ems.name}], id: [#{@ems.id}]"
    $log.info "#{log_header} Getting VMDB relationships for #{target.class} [#{target.name}] id: [#{target.id}]..."

    vr = {
      :ems_id => @ems.id,
      :ems_to_hosts => [],
      :ems_to_vms => [],
      :hosts_to_storages => Hash.new { |h, k| h[k] = Array.new },
      :hosts_to_vms => Hash.new { |h, k| h[k] = Array.new },
      :vm_to_storage => Hash.new { |h, k| h[k] = Array.new },

      :ems_to_folders => [],
      :ems_to_clusters => [],
      :ems_to_rps => [],
      :folders_to_folders => Hash.new { |h, k| h[k] = Array.new },
      :folders_to_clusters => Hash.new { |h, k| h[k] = Array.new },
      :folders_to_hosts => Hash.new { |h, k| h[k] = Array.new },
      :folders_to_vms => Hash.new { |h, k| h[k] = Array.new },
      :clusters_to_hosts => Hash.new { |h, k| h[k] = Array.new },
      :clusters_to_rps => Hash.new { |h, k| h[k] = Array.new },
      :hosts_to_rps => Hash.new { |h, k| h[k] = Array.new },
      :rps_to_rps => Hash.new { |h, k| h[k] = Array.new },
      :rps_to_vms => Hash.new { |h, k| h[k] = Array.new },
    }

    # Find the target in the database
    case target
    when ExtManagementSystem
      target.hosts.each do |h|
        vr[:ems_to_hosts] << h.id

        ids = h.storages.collect { |s| s.id }
        vr[:hosts_to_storages][h.id] = ids unless ids.empty?
      end

      target.vms.each do |v|
        vr[:ems_to_vms] << v.id
        vr[:hosts_to_vms][v.host_id] << v.id unless v.host_id.nil?
        vr[:vm_to_storage][v.id] << v.storage_id unless v.storage_id.nil?
      end

      target.ems_folders.each do |f|
        vr[:ems_to_folders] << f.id

        ids = f.folders.collect { |f2| f2.id }
        vr[:folders_to_folders][f.id] = ids unless ids.empty?

        ids = f.clusters.collect { |c| c.id }
        vr[:folders_to_clusters][f.id] = ids unless ids.empty?

        ids = f.hosts.collect { |h| h.id }
        vr[:folders_to_hosts][f.id] = ids unless ids.empty?

        ids = f.vms.collect { |v| v.id }
        vr[:folders_to_vms][f.id] = ids unless ids.empty?
      end

      target.ems_clusters.each do |c|
        vr[:ems_to_clusters] << c.id

        ids = c.hosts.collect { |h| h.id }
        vr[:clusters_to_hosts][c.id] = ids unless ids.empty?
      end

      target.resource_pools.each do |r|
        vr[:ems_to_rps] << r.id
        if r.parent && [Host, EmsCluster].include?(r.parent.class)
          relat_type = (r.parent.class == Host ? :hosts_to_rps : :clusters_to_rps)
          vr[relat_type][r.parent.id] << r.id
        end

        ids = r.resource_pools.collect { |r2| r2.id }
        vr[:rps_to_rps][r.id] = ids unless ids.empty?

        ids = r.vms.collect { |v| v.id }
        vr[:rps_to_vms][r.id] = ids unless ids.empty?
      end

    when Host
      vr[:ems_to_hosts] << target.id

      ids = target.storages.collect { |s| s.id }
      vr[:hosts_to_storages][target.id] = ids unless ids.empty?

      target.vms.each do |v|
        vr[:ems_to_vms] << v.id
        vr[:hosts_to_vms][v.host_id] << v.id unless v.host_id.nil?
        vr[:vm_to_storage][v.id] << v.storage_id unless v.storage_id.nil?

        # Collect the "blue folder" relationships
        find_relats_vmdb_vm_ems_metadata(v, vr)

        # Collect the RPs from the VM up to the parent Host or Cluster
        find_relats_vmdb_vm_rp_metadata(v, vr)
      end

      # Collect the EMS metadata from this Host to the root
      find_relats_vmdb_host_ems_metadata(target, vr)

      # Collect the RPs from this Host down
      find_relats_vmdb_host_rp(target, vr)

    when Vm
      vr[:ems_to_vms] << target.id

      unless target.host_id.nil?
        vr[:ems_to_hosts] << target.host_id
        vr[:hosts_to_vms][target.host_id] << target.id

        vr[:hosts_to_storages][target.host_id] << target.storage_id unless target.storage_id.nil?
      end

      vr[:vm_to_storage][target.id] << target.storage_id unless target.storage_id.nil?

      # Collect the "blue folder" relationships
      find_relats_vmdb_vm_ems_metadata(target, vr)

      # Collect the RPs from the VM up to the parent Host or Cluster
      find_relats_vmdb_vm_rp_metadata(target, vr)

      # Collect the EMS metadata from the parent Host to the root
      find_relats_vmdb_host_ems_metadata(target.host, vr) unless target.host.nil?

    end
    $log.info "#{log_header} Getting VMDB relationships for #{target.class} [#{target.name}] id: [#{target.id}]...Complete"

    return vr
  end

  def find_relats_vmdb_host_ems_metadata(target, relats)
    old_relat, target.relationship_type = target.relationship_type, 'ems_metadata'

    parent = target
    loop do
      child = parent
      parent = child.parents[0]
      break if parent.nil?

      relat_type = case parent
      when EmsCluster then
        relats[:ems_to_clusters] << parent.id unless relats[:ems_to_clusters].include?(parent.id)
        :clusters_to_hosts

      when EmsFolder then
        relats[:ems_to_folders] << parent.id unless relats[:ems_to_folders].include?(parent.id)
        case child
        when EmsFolder then :folders_to_folders
        when EmsCluster then :folders_to_clusters
        when Host then :folders_to_hosts
        else nil
        end
      end

      relat = relats.fetch_path(relat_type, parent.id)
      relat << child.id unless relat.nil? || relat.include?(child.id)
    end

    target.relationship_type = old_relat
  end

  def find_relats_vmdb_host_rp(target, relats)
    return unless target.kind_of?(Host) || target.kind_of?(ResourcePool)

    old_relat, target.relationship_type = target.relationship_type, 'ems_metadata' if target.kind_of?(Host)

    target.children.each do |r|
      relat_type = case r
      when ResourcePool
        relats[:ems_to_rps] << r.id
        case target
        when Host then :hosts_to_rps
        when ResourcePool then :rps_to_rps
        else nil
        end
      when Vm then :rps_to_vms
      else next
      end

      relat = relats.fetch_path(relat_type, target.id)
      relat << r.id unless relat.nil? || relat.include?(r.id)

      find_relats_vmdb_host_rp(r, relats)
    end

    target.relationship_type = old_relat if target.kind_of?(Host)
  end

  def find_relats_vmdb_vm_ems_metadata(target, relats)
    return unless target.kind_of?(Vm)

    old_relat, target.relationship_type = target.relationship_type, 'ems_metadata'

    parent = target
    loop do
      child = parent
      parent = child.parents("EmsFolder")[0]
      break if parent.nil?

      relat_type = case child
      when Vm then :folders_to_vms
      when EmsFolder then :folders_to_folders
      else nil
      end

      relat = relats.fetch_path(relat_type, parent.id)
      relat << child.id unless relat.nil? || relat.include?(child.id)

      relats[:ems_to_folders] << parent.id unless relats[:ems_to_folders].include?(parent.id)

      break if parent.is_datacenter
    end

    target.relationship_type = old_relat
  end

  def find_relats_vmdb_vm_rp_metadata(target, relats)
    return unless target.kind_of?(Vm)

    old_relat, target.relationship_type = target.relationship_type, 'ems_metadata'

    parent = target
    loop do
      child = parent
      parent = child.kind_of?(Vm) ? child.parents("ResourcePool")[0] : child.parent
      break if parent.nil?

      relat_type = case parent
      when ResourcePool
        case child
        when Vm then :rps_to_vms
        when ResourcePool then :rps_to_rps
        else nil
        end
      when Host then :hosts_to_rps
      when EmsCluster then :clusters_to_rps
      else nil
      end

      relat = relats.fetch_path(relat_type, parent.id)
      relat << child.id unless relat.nil? || relat.include?(child.id)

      break if relat.nil? || parent.kind_of?(Host) || parent.kind_of?(EmsCluster)

      relats[:ems_to_rps] << parent.id unless relats[:ems_to_rps].include?(parent.id)
    end

    target.relationship_type = old_relat
  end

  def do_relat_compare(type, prev_relats, new_relats)
    $log.debug "MIQ(RefresherRelatsMixin.do_relat_compare) EMS: [#{@ems.name}], id: [#{@ems.id}] Updating #{type.to_s.titleize} relationships"
    if new_relats[type].kind_of?(Array) || prev_relats[type].kind_of?(Array)
      # Case where we have a single set of ids
      disconnect_proc, connect_proc = yield
      do_relat_compare_ids(prev_relats[type], new_relats[type], disconnect_proc, connect_proc)
    else
      # Case where we have multiple sets of ids
      (prev_relats[type].keys | new_relats[type].keys).each do |k|
        disconnect_proc, connect_proc = yield(k)
        do_relat_compare_ids(prev_relats[type][k], new_relats[type][k], disconnect_proc, connect_proc)
      end
    end
  end

  def do_relat_compare_ids(prev_ids, new_ids, disconnect_proc, connect_proc)
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
          $log.error "MIQ(RefresherRelatsMixin.do_relat_compare_ids) EMS: [#{@ems.name}], id: [#{@ems.id}] An error occurred while disconnecting id [#{p}]: #{err}"
          $log.log_backtrace(err)
        end
      end
    end

    unless new_ids.nil? || connect_proc.nil?
      new_ids.each do |n|
        begin
          connect_proc.call(n)
        rescue => err
          $log.error "MIQ(RefresherRelatsMixin.do_relat_compare_ids) EMS: [#{@ems.name}], id: [#{@ems.id}] An error occurred while connecting id [#{n}]: #{err}"
          $log.log_backtrace(err)
        end
      end
    end
  end

  def update_relats(target, prev_relats, new_relats)
    log_header = "MIQ(RefresherRelatsMixin.update_relats) EMS: [#{@ems.name}], id: [#{@ems.id}]"
    $log.debug "#{log_header} Updating relationships..."
    $log.debug "#{log_header} prev_relats: #{prev_relats.inspect}"
    $log.debug "#{log_header} new_relats:  #{new_relats.inspect}"

    # Check if the data coming in reflects a complete removal from VC
    if new_relats[:ems_to_hosts].empty? && new_relats[:ems_to_hosts].empty? && new_relats[:ems_to_vms].empty? &&
        new_relats[:hosts_to_storages].empty? && new_relats[:hosts_to_vms].empty? && new_relats[:vm_to_storage].empty?

      case target
      when ExtManagementSystem
        target.hosts.each { |h| h.disconnect_ems(@ems) }
        target.vms.each { |v| v.disconnect_ems(@ems) }

        target.ems_folders.destroy_all
        target.ems_clusters.destroy_all
        target.resource_pools.destroy_all
      when Host
        target.disconnect_ems(@ems)

        target.relationship_type = 'ems_metadata'
        target.remove_all_parents('EmsFolder')
        target.remove_all_parents('EmsCluster')
      when Vm
        target.disconnect_ems(@ems)

        target.relationship_type = 'ems_metadata'
        target.remove_all_parents('EmsFolder')
        target.remove_all_parents('ResourcePool')

        target.disconnect_host
      end
    else
      # Do the EMS to *, Folders to *, and Clusters to * relationships
      #   For these, we only disconnect when doing an EMS refresh since we don't have
      #   enough information in the filtered data for other refresh types
      do_disconnect = target.kind_of?(ExtManagementSystem)

      # Do the EMS to Hosts relationships
      do_relat_compare(:ems_to_hosts, prev_relats, new_relats) do
        [ do_disconnect ? Proc.new { |h| Host.find(h).disconnect_ems(@ems) } : nil, # Disconnect proc
          Proc.new { |h| Host.find(h).connect_ems(@ems) } ]                         # Connect proc
      end

      # Do the EMS to VMs relationships
      do_relat_compare(:ems_to_vms, prev_relats, new_relats) do
        [ do_disconnect ? Proc.new { |v| VmOrTemplate.find(v).disconnect_ems(@ems) } : nil, # Disconnect proc
          Proc.new { |v| VmOrTemplate.find(v).connect_ems(@ems) } ]                         # Connect proc
      end

      # Do the Folders to Folders relationships
      do_relat_compare(:folders_to_folders, prev_relats, new_relats) do |f|
        folder = EmsFolder.find(f)
        [ do_disconnect ? Proc.new { |f2| folder.remove_folder(EmsFolder.find(f2)) } : nil, # Disconnect proc
          Proc.new { |f2| folder.add_folder(EmsFolder.find(f2)) } ]                         # Connect proc
      end

      # Do the Folders to Clusters relationships
      do_relat_compare(:folders_to_clusters, prev_relats, new_relats) do |f|
        folder = EmsFolder.find(f)
        [ do_disconnect ? Proc.new { |c| folder.remove_cluster(EmsCluster.find(c)) } : nil, # Disconnect proc
          Proc.new { |c| folder.add_cluster(EmsCluster.find(c)) } ]                         # Connect proc
      end

      # Do the Folders to Hosts relationships
      do_relat_compare(:folders_to_hosts, prev_relats, new_relats) do |f|
        folder = EmsFolder.find(f)
        [ do_disconnect ? Proc.new { |h| folder.remove_host(Host.find(h)) } : nil, # Disconnect proc
          Proc.new { |h| folder.add_host(Host.find(h)) } ]                         # Connect proc
      end

      # Do the Folders to Vms relationships
      do_relat_compare(:folders_to_vms, prev_relats, new_relats) do |f|
        folder = EmsFolder.find(f)
        [ do_disconnect ? Proc.new { |v| folder.remove_vm(VmOrTemplate.find(v)) } : nil, # Disconnect proc
          Proc.new { |v| folder.add_vm(VmOrTemplate.find(v)) } ]                         # Connect proc
      end

      # Do the Clusters to ResourcePools relationships
      do_relat_compare(:clusters_to_rps, prev_relats, new_relats) do |c|
        cluster = EmsCluster.find(c)
        [ do_disconnect ? Proc.new { |r| cluster.remove_resource_pool(ResourcePool.find(r)) } : nil, # Disconnect proc
          Proc.new { |r| cluster.add_resource_pool(ResourcePool.find(r)) } ]                         # Connect proc
      end

      # Do the Clusters to Hosts relationships
      do_relat_compare(:clusters_to_hosts, prev_relats, new_relats) do |c|
        cluster = EmsCluster.find(c)
        [ do_disconnect ? Proc.new { |h| cluster.hosts.delete(Host.find(h)) } : nil, # Disconnect proc
          Proc.new { |h| cluster.hosts << Host.find(h) } ]                           # Connect proc
      end

      # Do the Hosts to * relationships, ResourcePool to * relationships
      #   For these, we only disconnect when doing an EMS or Host refresh since we don't
      #   have enough information in the filtered data for other refresh types
      do_disconnect ||= target.kind_of?(Host)

      # Do the Hosts to Storages relationships
      do_relat_compare(:hosts_to_storages, prev_relats, new_relats) do |h|
        host = Host.find(h)
        [ do_disconnect ? Proc.new { |s| host.disconnect_storage(Storage.find(s)) } : nil, # Disconnect proc
          Proc.new { |s| host.connect_storage(Storage.find(s)) } ]                         # Connect proc
      end

      # Do the Hosts to VMs relationships
      do_relat_compare(:hosts_to_vms, prev_relats, new_relats) do |h|
        host = Host.find(h)
        [ do_disconnect ? Proc.new { |v| VmOrTemplate.find(v).disconnect_host(host) } : nil, # Disconnect proc
          Proc.new { |v| VmOrTemplate.find(v).connect_host(host) } ]                         # Connect proc
      end

      # Do the Hosts to ResourcePools relationships
      do_relat_compare(:hosts_to_rps, prev_relats, new_relats) do |h|
        host = Host.find(h)
        [ do_disconnect ? Proc.new { |r| ResourcePool.find(r).remove_parent(host) } : nil, # Disconnect proc
          Proc.new { |r| ResourcePool.find(r).set_parent(host) } ]                         # Connect proc
      end

      # Do the ResourcePools to ResourcePools relationships
      do_relat_compare(:rps_to_rps, prev_relats, new_relats) do |r|
        rp = ResourcePool.find(r)
        [ do_disconnect ? Proc.new { |r2| rp.remove_resource_pool(ResourcePool.find(r2)) } : nil, # Disconnect proc
          Proc.new { |r2| rp.add_resource_pool(ResourcePool.find(r2)) } ]                         # Connect proc
      end

      # Do the VMs to * relationships
      #   We do disconnects for all refresh types since we have enough
      #   information in the filtered data for all refresh types

      # Do the ResourcePools to VMs relationships
      do_relat_compare(:rps_to_vms, prev_relats, new_relats) do |r|
        rp = ResourcePool.find(r)
        [ Proc.new { |v| rp.remove_vm(VmOrTemplate.find(v)) }, # Disconnect proc
          Proc.new { |v| rp.add_vm(VmOrTemplate.find(v)) } ]   # Connect proc
      end

      # Do the VMs to Storage relationships
      do_relat_compare(:vm_to_storage, prev_relats, new_relats) do |v|
        vm = VmOrTemplate.find(v)
        [ Proc.new { |s| vm.disconnect_storage(Storage.find(s)) }, # Disconnect proc
          Proc.new { |s| vm.connect_storage(Storage.find(s)) } ]   # Connect proc
      end

      # Do these EMS to * relationships last as they actually destroy elements
      #   as opposed to just disconnecting them

      # Do the EMS to Folders relationships
      do_relat_compare(:ems_to_folders, prev_relats, new_relats) do
        [ target.kind_of?(ExtManagementSystem) ? Proc.new { |f| EmsFolder.destroy(f) } : nil, # Disconnect proc
          Proc.new { |f| @ems.ems_folders << EmsFolder.find(f) } ]                            # Connect proc
      end

      # Do the EMS to Clusters relationships
      do_relat_compare(:ems_to_clusters, prev_relats, new_relats) do
        [ target.kind_of?(ExtManagementSystem) ? Proc.new { |c| EmsCluster.destroy(c) } : nil, # Disconnect proc
          Proc.new { |c| @ems.ems_clusters << EmsCluster.find(c) } ]                           # Connect proc
      end

      # Do the EMS to ResourcePools relationships
      do_relat_compare(:ems_to_rps, prev_relats, new_relats) do
        [ target.kind_of?(ExtManagementSystem) ? Proc.new { |r| ResourcePool.destroy(r) } : nil, # Disconnect proc
          Proc.new { |r| @ems.resource_pools << ResourcePool.find(r) } ]                         # Connect proc
      end

      # Update the default RPs and their names to reflect their parent relationships,
      #   now that RPs are connected to their parents
      ResourcePool.find_all_by_id(new_relats[:ems_to_rps]).each do |rp|
        unless rp.parent.nil?
          # Mark RPs default that are only immediately under a Host or Cluster
          rp.is_default = [EmsCluster, Host].include?(rp.parent.class)
          rp.name = "Default for #{Dictionary.gettext(rp.parent.class.to_s, :type => :model, :notfound => :titleize)} #{rp.parent.name}" if rp.is_default
          rp.save
        end
      end

      # Hook up a relationship from the ems to the root folder
      @ems.remove_all_folders
      root = @ems.ems_folders.reload.detect { |f| f.parent.nil? }  # Reload so that the cached ems_folders get the updates from remove_all_folders
      unless root.nil?
        @ems.add_folder(root)
      else
        $log.warn "#{log_header} Unable to find a root folder."
      end
    end
    $log.debug "#{log_header} Updating relationships...Complete"
  end
end
