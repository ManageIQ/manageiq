module EmsRefresh::SaveInventory

  def save_ems_inventory(ems, hashes, target = nil)
    case ems
    when EmsCloud; save_ems_cloud_inventory(ems, hashes, target)
    when EmsInfra; save_ems_infra_inventory(ems, hashes, target)
    end
  end

  #
  # Shared between Cloud and Infra
  #

  def save_vms_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?
    log_header = "MIQ(#{self.name}.save_vms_inventory) EMS: [#{ems.name}], id: [#{ems.id}]"

    disconnects = if target.kind_of?(ExtManagementSystem) || target.kind_of?(Host)
      target.vms_and_templates(true).to_a.dup
    elsif target.kind_of?(Vm)
      [target.ruby_clone]
    else
      []
    end

    child_keys = [:operating_system, :hardware, :custom_attributes, :snapshots]
    extra_infra_keys = [:host, :ems_cluster, :storage, :storages, :raw_power_state, :parent_vm]
    extra_cloud_keys = [
      :flavor,
      :availability_zone,
      :cloud_tenant,
      :cloud_network,
      :cloud_subnet,
      :security_groups,
      :key_pairs,
      :orchestration_stack,
    ]
    remove_keys = child_keys + extra_infra_keys + extra_cloud_keys

    # Query for all of the Vms once across all EMSes, to handle any moving VMs
    vms_uids = hashes.collect { |h| h[:uid_ems] }.compact
    vms = VmOrTemplate.find_all_by_uid_ems(vms_uids)
    dup_vms_uids = (vms_uids.duplicates + vms.collect(&:uid_ems).duplicates).uniq.sort
    $log.info "#{log_header} Duplicate unique values found: #{dup_vms_uids.inspect}" unless dup_vms_uids.empty?

    invalids_found = false
    hashes.each do |h|
      # Backup keys that cannot be written directly to the database
      key_backup = backup_keys(h, remove_keys)

      h[:ems_id]                 = ems.id
      h[:host_id]                = key_backup.fetch_path(:host, :id)
      h[:ems_cluster_id]         = key_backup.fetch_path(:ems_cluster, :id)
      h[:storage_id]             = key_backup.fetch_path(:storage, :id)
      h[:flavor_id]              = key_backup.fetch_path(:flavor, :id)
      h[:availability_zone_id]   = key_backup.fetch_path(:availability_zone, :id)
      h[:cloud_network_id]       = key_backup.fetch_path(:cloud_network, :id)
      h[:cloud_subnet_id]        = key_backup.fetch_path(:cloud_subnet, :id)
      h[:cloud_tenant_id]        = key_backup.fetch_path(:cloud_tenant, :id)
      h[:orchestration_stack_id] = key_backup.fetch_path(:orchestration_stack, :id)

      begin
        raise MiqException::MiqIncompleteData if h[:invalid]

        # Find the Vm in the database with the current uid_ems.  In the event
        #   of duplicates, try to determine which one is correct.
        found = vms.select { |v| v.uid_ems == h[:uid_ems] }
        if found.length > 1 || (found.length == 1 && found.first.ems_id)
          found_dups = found
          found = found_dups.select { |v| v.ems_id == h[:ems_id] && (v.ems_ref.nil? || v.ems_ref == h[:ems_ref]) }
          if found.empty?
            found_dups = found_dups.select { |v| v.ems_id.nil? }
            found = found_dups.select { |v| v.ems_ref == h[:ems_ref] }
            found = found_dups if found.empty?
          end
        end
        found = found.first

        if found.nil?
          $log.info("#{log_header} Creating Vm [#{h[:name]}] location: [#{h[:location]}] storage id: [#{h[:storage_id]}] uid_ems: [#{h[:uid_ems]}] ems_ref: [#{h[:ems_ref]}]")

          # Handle the off chance that we are adding an "unknown" Vm to the db
          h[:location] = "unknown" if h[:location].blank?

          # build a type-specific vm or template
          found = ems.vms_and_templates.build(h)
        else
          vms.delete(found)

          h.delete(:type)

          $log.info("#{log_header} Updating Vm [#{found.name}] id: [#{found.id}] location: [#{found.location}] storage id: [#{found.storage_id}] uid_ems: [#{found.uid_ems}] ems_ref: [#{h[:ems_ref]}]")
          found.update_attributes!(h)
          disconnects.delete(found)
        end

        # Set the raw power state
        found.raw_power_state = key_backup[:raw_power_state]

        link_habtm(found, key_backup[:storages], :storages, Storage)
        link_habtm(found, key_backup[:security_groups], :security_groups, SecurityGroup)
        link_habtm(found, key_backup[:key_pairs], :key_pairs, AuthKeyPairCloud)
        save_child_inventory(found, key_backup, child_keys)

        found.save!
        h[:id] = found.id
      rescue => err
        # If a vm failed to process, mark it as invalid and log an error
        h[:invalid] = invalids_found = true
        name = h[:name] || h[:uid_ems] || h[:ems_ref]
        $log.send(err.kind_of?(MiqException::MiqIncompleteData) ? :warn : :error, "#{log_header} Processing Vm: [#{name}] failed with error [#{err}]. Skipping Vm.")
        $log.log_backtrace(err) unless err.kind_of?(MiqException::MiqIncompleteData)
      ensure
        restore_keys(h, remove_keys, key_backup)
      end
    end

    # Handle genealogy link ups
    vm_ids = hashes.collect { |h| !h[:invalid] && h.has_key_path?(:parent_vm, :id) ? [h[:id], h.fetch_path(:parent_vm, :id)] : nil }.flatten.compact.uniq
    unless vm_ids.empty?
      $log.info("#{log_header} Updating genealogy connections.")
      vms = VmOrTemplate.find_all_by_id(vm_ids)
      hashes.each do |h|
        child_id = h[:id]
        parent_id = h.fetch_path(:parent_vm, :id)
        next if child_id.blank? || parent_id.blank?

        parent = vms.detect { |v| v.id == parent_id }
        child = vms.detect { |v| v.id == child_id }
        next if parent.blank? || child.blank?

        parent.with_relationship_type('genealogy') { parent.set_child(child) }
      end
    end

    unless disconnects.empty?
      if invalids_found
        $log.warn("#{log_header} Since failures occurred, not disconnecting for Vms #{self.log_format_deletes(disconnects)}")
      else
        $log.info("#{log_header} Disconnecting Vms #{self.log_format_deletes(disconnects)}")
        disconnects.each(&:disconnect_inv)
      end
    end
  end

  def save_operating_system_inventory(parent, hash)
    return if hash.nil?

    # Only set a value if we do not have one and we have not collected scan metadata.
    # Otherwise an ems may not contain the proper value and we do not want to overwrite
    # the value collected during our metadata scan.
    return if parent.kind_of?(Vm) && !(parent.drift_states.size.zero? || parent.operating_system.nil? || parent.operating_system.product_name.blank?)

    self.save_inventory_single(:operating_system, OperatingSystem, parent, hash)
  end

  def save_hardware_inventory(parent, hash)
    return if hash.nil?
    self.save_inventory_single(:hardware, Hardware, parent, hash, [:disks, :guest_devices, :networks])
    parent.save!
  end

  def save_guest_devices_inventory(hardware, hashes)
    return if hashes.nil?

    # Update the associated ids
    hashes.each do |h|
      h[:switch_id] = h.fetch_path(:switch, :id)
      h[:lan_id] = h.fetch_path(:lan, :id)

      if h[:network]
        # Save the hardware to force an id if not found
        hardware.save! if hardware.id.nil?
        h[:network][:hardware_id] = hardware.id
      end
    end

    deletes = hardware.guest_devices.where(:device_type => ["ethernet", "storage"]).to_a.dup
    self.save_inventory_multi(:guest_devices, GuestDevice, hardware, hashes, deletes, [:device_type, :uid_ems], [:network, :miq_scsi_targets], [:switch, :lan])
    self.store_ids_for_new_records(hardware.guest_devices, hashes, [:device_type, :uid_ems])
  end

  def save_disks_inventory(hardware, hashes)
    return if hashes.nil?

    # Update the associated ids
    hashes.each do |h|
      h[:storage_id] = h.fetch_path(:storage, :id)
      h[:backing_id] = h.fetch_path(:backing, :id)
    end

    save_inventory_multi(:disks, Disk, hardware, hashes, true, [:controller_type, :location], nil, [:storage, :backing])
  end

  def save_network_inventory(guest_device, hash)
    if hash.nil?
      guest_device.network = nil
    else
      self.save_inventory_single(:network, Network, guest_device, hash, nil, :guest_device)
      hash[:id] = guest_device.network.id
    end
  end

  def save_networks_inventory(hardware, hashes, mode = :refresh)
    return if hashes.nil?

    case mode
    when :refresh
      deletes = hardware.networks(true).dup
      # Remove networks that were already saved via guest devices
      saved_hashes, new_hashes = hashes.partition { |h| h[:id] }
      saved_hashes.each { |h| deletes.delete_if { |d| d.id == h[:id] } } unless deletes.empty? || saved_hashes.empty?

      self.save_inventory_multi(:networks, Network, hardware, new_hashes, deletes, :ipaddress, nil, :guest_device)
    when :scan
      save_inventory_multi(:networks, Network, hardware, hashes, true, [:description, :guid])
    end
  end

  def save_system_services_inventory(parent, hashes, mode = :refresh)
    deletes = mode == :scan ? true : nil
    self.save_inventory_multi(:system_services, SystemService, parent, hashes, deletes, [:typename, :name])
  end

  def save_guest_applications_inventory(parent, hashes)
    save_inventory_multi(:guest_applications, GuestApplication, parent, hashes, true, [:arch, :typename, :name, :version])
  end

  def save_advanced_settings_inventory(parent, hashes)
    save_inventory_multi(:advanced_settings, AdvancedSetting, parent, hashes, true, :name)
  end

  def save_patches_inventory(parent, hashes)
    save_inventory_multi(:patches, Patch, parent, hashes, true, :name)
  end

  def save_os_processes_inventory(os, hashes)
    save_inventory_multi(:processes, OsProcess, os, hashes, true, :pid)
  end

  def save_firewall_rules_inventory(parent, hashes, mode = :refresh)
    return if hashes.nil?

    find_key =
      case mode
      when :refresh
        # Leaves out the source_security_group_id, as we will set that later
        #   after all security_groups have been saved and ids obtained.
        if parent.kind_of?(SecurityGroupOpenstack)
          :ems_ref
        else
          [:direction, :host_protocol, :port, :end_port, :source_ip_range]
        end
      when :scan
        :name
      end

    save_inventory_multi(:firewall_rules, FirewallRule, parent, hashes, true, find_key, nil, [:source_security_group])

    parent.save!
    self.store_ids_for_new_records(parent.firewall_rules, hashes, find_key)
  end

  def save_custom_attributes_inventory(parent, hashes)
    save_inventory_multi(:ems_custom_attributes, CustomAttribute, parent, hashes, true, [:section, :name])
  end

  def save_filesystems_inventory(parent, hashes)
    save_inventory_multi(:filesystems, Filesystem, parent, hashes, true, :name)
  end

  def save_snapshots_inventory(vm, hashes)
    return if hashes.nil?

    hashes.each { |h| h[:parent_id] = nil } # Delink all snapshots

    save_inventory_multi(:snapshots, Snapshot, vm, hashes, true, :uid)

    # Reset the relationship tree for the snapshots
    vm.snapshots.each do |s|
      if s.parent_uid
        parent = vm.snapshots.detect { |s2| s2.uid == s.parent_uid }
        s.update_attribute(:parent_id, parent ? parent.id : nil)
      end
    end
  end

  def save_event_logs_inventory(os, hashes)
    save_inventory_multi(:event_logs, EventLog, os, hashes, true, :uid)
  end
end
