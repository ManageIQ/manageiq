#
# Calling order for EmsInfra:
# - ems
#   - storages
#   - ems_clusters
#   - hosts
#     - storages (link)
#     - operating_system
#     - switches
#       - lans
#     - hardware
#       - guest_devices
#         - network
#         - miq_scsi_targets
#           - miq_scsi_luns
#       - networks (if not already saved via guest_devices)
#     - system_services
#   - vms
#     - storages (link)
#     - operating_system
#     - hardware
#       - disks
#       - guest_devices
#     - custom_attributes
#     - snapshots
#   - ems_folders
#   - resource_pools
#   - customization_specs
#
#   - link
#

module EmsRefresh::SaveInventoryInfra
  def save_ems_infra_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "MIQ(#{self.name}.save_ems_infra_inventory) EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes.blank? || (hashes[:hosts].blank? && hashes[:vms].blank? && hashes[:storages].blank?)
      target.disconnect_inv
      return
    end

    prev_relats = self.vmdb_relats(target)

    $log.info("#{log_header} Saving EMS Inventory...")
    if debug_trace
      require 'yaml'
      $log.debug "#{log_header} hashes:\n#{YAML.dump(hashes)}"
    end

    child_keys = [:storages, :clusters, :hosts, :vms, :folders, :resource_pools, :customization_specs]

    # Save and link other subsections
    child_keys.each do |k|
      meth = [:folders, :clusters].include?(k) ? "ems_#{k}" : k
      self.send("save_#{meth}_inventory", ems, hashes[k], target)
    end

    ems.save!
    hashes[:id] = ems.id

    $log.info("#{log_header} Saving EMS Inventory...Complete")

    new_relats = self.hashes_relats(hashes)
    self.link_ems_inventory(ems, target, prev_relats, new_relats)

    return ems
  end

  def save_storages_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?
    log_header = "MIQ(#{self.name}.save_storages_inventory) EMS: [#{ems.name}], id: [#{ems.id}]"

    # Query for all of the storages ahead of time
    locs, names = hashes.partition { |h| h[:location] }
    locs.collect!  { |h| h[:location] }
    names.collect! { |h| h[:name] }
    locs  = Storage.all(:conditions => ["location IN (?)", locs]) unless locs.empty?
    names = Storage.all(:conditions => ["location IS NULL AND name IN (?)", names]) unless names.empty?

    hashes.each do |h|
      found = if h[:location]
        locs.detect { |s| s.location == h[:location] && s.ems_ref == h[:ems_ref] }
      else
        names.detect { |s| s.name == h[:name] && s.ems_ref == h[:ems_ref] }
      end

      if found.nil?
        $log.info("#{log_header} Creating Storage [#{h[:name]}] location: [#{h[:location]}]")
        found = Storage.create(h)
      else
        $log.info("#{log_header} Updating Storage [#{found.name}] id: [#{found.id}] location: [#{found.location}]")
        found.update_attributes!(h)
      end

      h[:id] = found.id
    end
  end

  def save_hosts_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?
    log_header = "MIQ(#{self.name}.save_hosts_inventory) EMS: [#{ems.name}], id: [#{ems.id}]"

    disconnects = if target.kind_of?(ExtManagementSystem)
      target.hosts(true).dup
    elsif target.kind_of?(Host)
      [target.clone]
    else
      []
    end

    child_keys = [:operating_system, :switches, :hardware, :system_services]
    extra_keys = [:ems_cluster, :storages, :vms, :power_state, :ems_children]
    remove_keys = child_keys + extra_keys

    invalids_found = false
    hashes.each do |h|
      # Backup keys that cannot be written directly to the database
      key_backup = backup_keys(h, remove_keys)

      h[:ems_cluster_id] = key_backup.fetch_path(:ems_cluster, :id)

      begin
        raise MiqException::MiqIncompleteData if h[:invalid]

        # Find this host record
        found = nil
        if h[:ems_ref]
          $log.debug "#{log_header} Host database lookup - ems_ref: [#{h[:ems_ref]}] ems_id: [#{ems.id}]"
          found = Host.find_by_ems_ref_and_ems_id(h[:ems_ref], ems.id)
        end

        if found.nil?
          if h[:hostname].nil? && h[:ipaddress].nil?
            $log.debug "#{log_header} Host database lookup - name [#{h[:name]}]"
            found = ems.hosts.detect { |e| e.name.downcase == h[:name].downcase }
          elsif ["localhost", "localhost.localdomain", "127.0.0.1"].include_none?(h[:hostname], h[:ipaddress])
            # host = Host.find_by_hostname(hostname) has a risk of creating duplicate hosts
            $log.debug "#{log_header} Host database lookup - hostname: [#{h[:hostname]}] IP: [#{h[:ipaddress]}]"
            found = Host.lookUpHost(h[:hostname], h[:ipaddress])
          end
        end

        if found.nil?
          $log.info("#{log_header} Creating Host [#{h[:name]}] hostname: [#{h[:hostname]}] IP: [#{h[:ipaddress]}] ems_ref: [#{h[:ems_ref]}]")
          found = ems.hosts.build(h)
        else
          $log.info("#{log_header} Updating Host [#{found.name}] id: [#{found.id}] hostname: [#{found.hostname}] IP: [#{found.ipaddress}] ems_ref: [#{h[:ems_ref]}]")
          h[:ems_id] = ems.id  # Steal this host from the previous EMS

          # Adjust the names so they do not keep changing in the event of DNS problems
          ip_part  =  %r{[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+}
          ip_whole = %r{^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$}

          #   Keep the previous name unless it's nil
          h[:name] = found.name unless found.name.nil?

          # Keep the previous ip address if we don't have a new one or the new one is not an ip address
          h[:ipaddress] = found.ipaddress if h[:ipaddress].nil? || (h[:ipaddress] !~ ip_whole)

          #   Keep the previous hostname unless it's nil or it's an ip address
          h[:hostname] = found.hostname unless found.hostname.nil? || (found.hostname =~ ip_whole)

          #   Update the name to the hostname if the new name has an ip address,
          #   and the new hostname is not an ip address
          h[:name] = h[:hostname] if h[:name] =~ ip_part && !(h[:hostname] =~ ip_whole)

          h.delete(:type)

          found.update_attributes(h)
        end

        # Make sure to set the type as Hosts use Single-Table Inheritance (STI)
        # TODO: Verify if this is needed anymore since :type is now supported with the NewWithTypeStiMixin
        found.type ||= found.detect_type || ems.class.default_host_type

        # Handle duplicate names coming in because of duplicate hostnames.
        begin
          found.save!
        rescue ActiveRecord::RecordInvalid
          raise if found.errors[:name].blank?
          old_name = Host.first(:conditions => ["name LIKE ?", "#{found.name.sub(/ - \d+$/, "")}%"], :order => "name DESC").name
          found.name = old_name =~ / - \d+$/ ? old_name.succ : "#{old_name} - 2"
          retry
        end

        disconnects.delete(found)

        # Set the power state
        found.state = key_backup[:power_state] unless key_backup[:power_state].nil?

        link_habtm(found, key_backup[:storages], :storages, Storage, target.kind_of?(ExtManagementSystem) || target.kind_of?(Host))
        save_child_inventory(found, key_backup, child_keys)

        found.save!
        h[:id] = found.id
      rescue => err
        # If a host failed to process, mark it as invalid and log an error
        h[:invalid] = invalids_found = true
        name = h[:name] || h[:uid_ems] || h[:hostname] || h[:ipaddress] || h[:ems_ref]
        $log.send(err.kind_of?(MiqException::MiqIncompleteData) ? :warn : :error, "#{log_header} Processing Host: [#{name}] failed with error [#{err.class}: #{err.to_s}]. Skipping Host.")
        $log.log_backtrace(err) unless err.kind_of?(MiqException::MiqIncompleteData)
      ensure
        restore_keys(h, remove_keys, key_backup)
      end
    end

    unless disconnects.empty?
      if invalids_found
        $log.warn("#{log_header} Since failures occurred, not disconnecting for Hosts #{self.log_format_deletes(disconnects)}")
      else
        $log.info("#{log_header} Disconnecting Hosts #{self.log_format_deletes(disconnects)}")
        disconnects.each { |h| h.disconnect_inv }
      end
    end
  end

  def save_ems_folders_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.ems_folders(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.ems_folders.dup
    else
      []
    end

    self.save_inventory_multi(:ems_folders, EmsFolder, ems, hashes, deletes, :uid_ems, nil, :ems_children)
    self.store_ids_for_new_records(ems.ems_folders, hashes, :uid_ems)
  end

  def save_ems_clusters_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.ems_clusters(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.ems_clusters.dup
    else
      []
    end

    self.save_inventory_multi(:ems_clusters, EmsCluster, ems, hashes, deletes, :uid_ems, nil, :ems_children)
    self.store_ids_for_new_records(ems.ems_clusters, hashes, :uid_ems)
  end

  def save_resource_pools_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    ems.resource_pools(true)
    deletes = if target.kind_of?(ExtManagementSystem)
      ems.resource_pools.dup
    elsif target.kind_of?(Host)
      target.all_resource_pools_with_default.dup
    else
      []
    end

    self.save_inventory_multi(:resource_pools, ResourcePool, ems, hashes, deletes, :uid_ems, nil, :ems_children)
    self.store_ids_for_new_records(ems.resource_pools, hashes, :uid_ems)
  end

  def save_customization_specs_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    deletes = ems.customization_specs(true).dup
    self.save_inventory_multi(:customization_specs, CustomizationSpec, ems, hashes, deletes, :name)
  end

  def save_miq_scsi_targets_inventory(guest_device, hashes)
    return if hashes.nil?
    deletes = guest_device.miq_scsi_targets(true).dup
    self.save_inventory_multi(:miq_scsi_targets, MiqScsiTarget, guest_device, hashes, deletes, :uid_ems, :miq_scsi_luns)
  end

  def save_miq_scsi_luns_inventory(miq_scsi_target, hashes)
    return if hashes.nil?
    deletes = miq_scsi_target.miq_scsi_luns(true).dup
    self.save_inventory_multi(:miq_scsi_luns, MiqScsiLun, miq_scsi_target, hashes, deletes, :uid_ems)
  end

  def save_switches_inventory(host, hashes)
    return if hashes.nil?
    deletes = host.switches(true).dup
    self.save_inventory_multi(:switches, Switch, host, hashes, deletes, :uid_ems, :lans)

    host.save!

    # Collect the ids of switches and lans after saving
    hashes.each do |sh|
      switch = host.switches.detect { |s| s.uid_ems == sh[:uid_ems] }
      sh[:id] = switch.id

      next if sh[:lans].nil?
      sh[:lans].each do |lh|
        lan = switch.lans.detect { |l| l.uid_ems == lh[:uid_ems] }
        lh[:id] = lan.id
      end
    end
  end

  def save_lans_inventory(switch, hashes)
    return if hashes.nil?
    deletes = switch.lans(true).dup
    self.save_inventory_multi(:lans, Lan, switch, hashes, deletes, :uid_ems)
  end

  def save_storage_files_inventory(storage, hashes)
    return if hashes.nil?
    deletes = storage.storage_files(true).dup
    self.save_inventory_multi(:storage_files, StorageFile, storage, hashes, deletes, :name)
  end
end
