module EmsRefresh::SaveInventory
  def save_ems_inventory(ems, hashes, target = nil)
    case ems
    when EmsCloud                                           then save_ems_cloud_inventory(ems, hashes, target)
    when EmsInfra                                           then save_ems_infra_inventory(ems, hashes, target)
    when ManageIQ::Providers::ConfigurationManager          then save_configuration_manager_inventory(ems, hashes, target)
    when ManageIQ::Providers::ContainerManager              then save_ems_container_inventory(ems, hashes, target)
    when ManageIQ::Providers::NetworkManager                then save_ems_network_inventory(ems, hashes, target)
    when ManageIQ::Providers::StorageManager::CinderManager then save_ems_cinder_inventory(ems, hashes, target)
    when ManageIQ::Providers::StorageManager::SwiftManager  then save_ems_swift_inventory(ems, hashes, target)
    when ManageIQ::Providers::MiddlewareManager             then save_ems_middleware_inventory(ems, hashes, target)
    end
  end

  #
  # Shared between Cloud and Infra
  #

  def save_vms_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    disconnects = if target.kind_of?(ExtManagementSystem) || target.kind_of?(Host)
                    target.vms_and_templates.reload.to_a
                  elsif target.kind_of?(Vm)
                    [target.ruby_clone]
                  else
                    []
                  end

    child_keys = [:operating_system, :hardware, :custom_attributes, :snapshots, :advanced_settings]
    extra_infra_keys = [:host, :ems_cluster, :storage, :storages, :storage_profile, :raw_power_state, :parent_vm]
    extra_cloud_keys = [
      :flavor,
      :availability_zone,
      :cloud_tenant,
      :cloud_tenants,
      :cloud_network,
      :cloud_subnet,
      :security_groups,
      :key_pairs,
      :orchestration_stack,
    ]
    remove_keys = child_keys + extra_infra_keys + extra_cloud_keys

    # Query for all of the Vms once across all EMSes, to handle any moving VMs
    vms_uids = hashes.collect { |h| h[:uid_ems] }.compact
    vms = VmOrTemplate.where(:uid_ems => vms_uids).to_a
    disconnects_index = disconnects.index_by { |vm| vm }
    vms_by_uid_ems = vms.group_by(&:uid_ems)
    dup_vms_uids = (vms_uids.duplicates + vms.collect(&:uid_ems).duplicates).uniq.sort
    _log.info "#{log_header} Duplicate unique values found: #{dup_vms_uids.inspect}" unless dup_vms_uids.empty?

    invalids_found = false
    # Clear vms, so GC can clean them
    vms = nil

    ActiveRecord::Base.transaction do
      hashes.each do |h|
        # Backup keys that cannot be written directly to the database
        key_backup = backup_keys(h, remove_keys)

        h[:ems_id]                 = ems.id
        h[:host_id]                = key_backup.fetch_path(:host, :id) || key_backup.fetch_path(:host).try(:id)
        h[:ems_cluster_id]         = key_backup.fetch_path(:ems_cluster, :id) || key_backup.fetch_path(:ems_cluster).try(:id)
        h[:storage_id]             = key_backup.fetch_path(:storage, :id)
        h[:storage_profile_id]     = key_backup.fetch_path(:storage_profile, :id)
        h[:flavor_id]              = key_backup.fetch_path(:flavor, :id)
        h[:availability_zone_id]   = key_backup.fetch_path(:availability_zone, :id)
        h[:cloud_network_id]       = key_backup.fetch_path(:cloud_network, :id)
        h[:cloud_subnet_id]        = key_backup.fetch_path(:cloud_subnet, :id)
        h[:cloud_tenant_id]        = key_backup.fetch_path(:cloud_tenant, :id)
        h[:cloud_tenant_ids]       = key_backup.fetch_path(:cloud_tenants).compact.map { |x| x[:id] } if key_backup.fetch_path(:cloud_tenants, 0, :id)
        h[:orchestration_stack_id] = key_backup.fetch_path(:orchestration_stack, :id)
        begin
          raise MiqException::MiqIncompleteData if h[:invalid]

          # Find the Vm in the database with the current uid_ems.  In the event
          #   of duplicates, try to determine which one is correct.
          found = vms_by_uid_ems[h[:uid_ems]] || []

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
            _log.info("#{log_header} Creating Vm [#{h[:name]}] location: [#{h[:location]}] storage id: [#{h[:storage_id]}] uid_ems: [#{h[:uid_ems]}] ems_ref: [#{h[:ems_ref]}]")

            # Handle the off chance that we are adding an "unknown" Vm to the db
            h[:location] = "unknown" if h[:location].blank?

            # build a type-specific vm or template
            found = ems.vms_and_templates.klass.new(h)
          else
            vms_by_uid_ems[h[:uid_ems]].delete(found)
            h.delete(:type)

            _log.info("#{log_header} Updating Vm [#{found.name}] id: [#{found.id}] location: [#{found.location}] storage id: [#{found.storage_id}] uid_ems: [#{found.uid_ems}] ems_ref: [#{h[:ems_ref]}]")
            found.update_attributes!(h)
            disconnects_index.delete(found)
          end

          # Set the raw power state
          found.raw_power_state = key_backup[:raw_power_state]

          link_habtm(found, key_backup[:storages], :storages, Storage)
          link_habtm(found, key_backup[:key_pairs], :key_pairs, ManageIQ::Providers::CloudManager::AuthKeyPair)
          save_child_inventory(found, key_backup, child_keys)

          found.save!
          h[:id] = found.id
        rescue => err
          # If a vm failed to process, mark it as invalid and log an error
          h[:invalid] = invalids_found = true
          name = h[:name] || h[:uid_ems] || h[:ems_ref]
          if err.kind_of?(MiqException::MiqIncompleteData)
            _log.warn("#{log_header} Processing Vm: [#{name}] failed with error [#{err}]. Skipping Vm.")
          else
            raise if EmsRefresh.debug_failures
            _log.error("#{log_header} Processing Vm: [#{name}] failed with error [#{err}]. Skipping Vm.")
            _log.log_backtrace(err)
          end
        ensure
          restore_keys(h, remove_keys, key_backup)
        end
      end
    end

    # Handle genealogy link ups
    # TODO: can we use _object
    vm_ids = hashes.flat_map { |h| !h[:invalid] && h.has_key_path?(:parent_vm, :id) ? [h[:id], h.fetch_path(:parent_vm, :id)] : [] }.uniq
    unless vm_ids.empty?
      _log.info("#{log_header} Updating genealogy connections.")
      vms = VmOrTemplate.where(:id => vm_ids).index_by(&:id)
      hashes.each do |h|
        parent = vms[h.fetch_path(:parent_vm, :id)]
        child = vms[h[:id]]

        parent.with_relationship_type('genealogy') { parent.set_child(child) } if parent && child
      end
    end

    disconnects = disconnects_index.values

    unless disconnects.empty?
      if invalids_found
        _log.warn("#{log_header} Since failures occurred, not disconnecting for Vms #{log_format_deletes(disconnects)}")
      elsif target.kind_of?(Host)
        # The disconnected VMs may actually just be moved to another Host.  We
        # don't have enough information to fully disconnect from the EMS, so
        # queue up a targeted refresh on that VM.
        $log.warn("#{log_header} Queueing targeted refresh, since we do not have enough " \
                  "information to fully disconnect Vms #{log_format_deletes(disconnects)}")
        EmsRefresh.queue_refresh(disconnects)

        $log.info("#{log_header} Partially disconnecting Vms #{log_format_deletes(disconnects)}")
        disconnects.each(&:disconnect_host)
      else
        _log.info("#{log_header} Disconnecting Vms #{log_format_deletes(disconnects)}")
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

    save_inventory_single(:operating_system, parent, hash)
  end

  def save_hardware_inventory(parent, hash)
    return if hash.nil?
    save_inventory_single(:hardware, parent, hash, [:disks, :guest_devices, :networks])
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

    deletes = hardware.guest_devices.where(:device_type => ["ethernet", "storage"])
    save_inventory_multi(hardware.guest_devices, hashes, deletes, [:device_type, :uid_ems], [:network, :miq_scsi_targets], [:switch, :lan])
    store_ids_for_new_records(hardware.guest_devices, hashes, [:device_type, :uid_ems])
  end

  def save_disks_inventory(hardware, hashes)
    return if hashes.nil?

    # Update the associated ids
    hashes.each do |h|
      h[:storage_id]         = h.fetch_path(:storage, :id)
      h[:backing_id]         = h.fetch_path(:backing, :id)
      h[:storage_profile_id] = h.fetch_path(:storage_profile, :id)
    end

    save_inventory_multi(hardware.disks, hashes, :use_association, [:controller_type, :location], nil, [:storage, :backing, :storage_profile])
  end

  def save_network_inventory(guest_device, hash)
    if hash.nil?
      guest_device.network = nil
    else
      save_inventory_single(:network, guest_device, hash, nil, :guest_device)
      hash[:id] = guest_device.network.id
    end
  end

  def save_networks_inventory(hardware, hashes, mode = :refresh)
    return if hashes.nil?

    case mode
    when :refresh
      deletes = hardware.networks.reload.to_a

      # Remove networks that were already saved via guest devices
      saved_hashes, new_hashes = hashes.partition { |h| h[:id] }
      saved_hashes.each { |h| deletes.delete_if { |d| d.id == h[:id] } } unless deletes.empty? || saved_hashes.empty?

      save_inventory_multi(hardware.networks, new_hashes, deletes, [:ipaddress], nil, :guest_device)
    when :scan
      save_inventory_multi(hardware.networks, hashes, :use_association, [:description, :guid])
    end
  end

  def save_system_services_inventory(parent, hashes, mode = :refresh)
    return if hashes.nil?

    deletes = case mode
              when :refresh then nil
              when :scan    then :use_association
              end

    save_inventory_multi(parent.system_services, hashes, deletes, [:typename, :name])
  end

  def save_guest_applications_inventory(parent, hashes)
    save_inventory_multi(parent.guest_applications, hashes, :use_association, [:arch, :typename, :name, :version])
  end

  def save_advanced_settings_inventory(parent, hashes)
    save_inventory_multi(parent.advanced_settings, hashes, :use_association, [:name])
  end

  def save_patches_inventory(parent, hashes)
    save_inventory_multi(parent.patches, hashes, :use_association, [:name])
  end

  def save_os_processes_inventory(os, hashes)
    save_inventory_multi(os.processes, hashes, :use_association, [:pid])
  end

  def save_custom_attributes_inventory(parent, hashes, mode = :refresh)
    return if hashes.nil?

    deletes = case mode
              when :refresh then nil
              when :scan    then :use_association
              end

    save_inventory_multi(parent.custom_attributes, hashes, deletes, [:name, :section])
  end

  def save_ems_custom_attributes_inventory(parent, hashes)
    return if hashes.nil?
    save_inventory_multi(parent.ems_custom_attributes, hashes, :use_association, [:section, :name])
  end

  def save_filesystems_inventory(parent, hashes)
    save_inventory_multi(parent.filesystems, hashes, :use_association, [:name])
  end

  def save_snapshots_inventory(vm, hashes)
    return if hashes.nil?

    hashes.each { |h| h[:parent_id] = nil } # Delink all snapshots

    save_inventory_multi(vm.snapshots, hashes, :use_association, [:uid])

    # Reset the relationship tree for the snapshots
    vm.snapshots.each do |s|
      if s.parent_uid
        parent = vm.snapshots.detect { |s2| s2.uid == s.parent_uid }
        s.update_attribute(:parent_id, parent ? parent.id : nil)
      end
    end
  end

  def save_event_logs_inventory(os, hashes)
    save_inventory_multi(os.event_logs, hashes, :use_association, [:uid])
  end

  def save_new_target(target_hash)
    unless target_hash[:vm].nil?
      vm_hash = target_hash[:vm]
      existing_vm = VmOrTemplate.find_by(:ems_ref => vm_hash[:ems_ref], :ems_id => target_hash[:ems_id])
      unless existing_vm.nil?
        return existing_vm
      end

      ems = ExtManagementSystem.find_by_id(target_hash[:ems_id])
      old_cluster = get_cluster(ems, target_hash[:cluster], target_hash[:resource_pools], target_hash[:folders])

      vm_hash[:ems_cluster_id] = old_cluster[:id]

      new_vm = ems.vms_and_templates.create!(vm_hash)

      dc = old_cluster.parent_datacenter
      vm_folder = dc.children.select { |folder| folder.name == "vm" }[0]
      vm_folder.add_vm(new_vm)
      vm_folder.save!

      resource_pool = old_cluster.children.first
      resource_pool.add_vm(new_vm)
      resource_pool.save!

      new_vm
    end
  end
end
