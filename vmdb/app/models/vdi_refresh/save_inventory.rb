module VdiRefresh::SaveInventory
  def save_vdi_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "MIQ(#{self.name}.save_vdi_inventory) EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes.empty? || (hashes[:vdi_controllers].empty? && hashes[:vdi_desktop_pools].empty?)
      target.disconnect_inv
      return
    end

    #prev_relats = self.vmdb_relats(target)

    $log.info("#{log_header} Saving VDI Inventory...")
    if debug_trace
      require 'yaml'
      $log.debug "#{log_header} hashes:\n#{YAML.dump(hashes)}"
    end

    # Save and link other subsections
    child_keys = [:vdi_farm, :vdi_users, :vdi_endpoint_devices, :vdi_controllers, :vdi_desktop_pools]
    child_keys.each do |k|
      meth = [:folders].include?(k) ? "ems_#{k}" : k
      self.send("save_#{meth}_inventory", ems, hashes[k], target)
    end

    ems.save!

    $log.info("#{log_header} Saving VDI Inventory...Complete")

    #new_relats = self.hashes_relats(hashes)
    #self.link_vdi_inventory(ems, target, prev_relats, new_relats)

    return ems
  end

  def save_vdi_farm_inventory(ems, hash, target = nil)
    find_key = [:id]
    hash[:id] = ems.id
    record_index, record_index_columns = self.save_inventory_prep_record_index([ems], find_key)

    new_records = []
    save_inventory(:vdi_farm, VdiFarm, nil, hash, nil, new_records, record_index, record_index_columns, find_key, [], [:vdi_controllers, :vdi_desktop_pools])
    new_records.each {|nr| nr.save!}
  end

  def save_vdi_controllers_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?
    deletes = ems.vdi_controllers(true).dup

    find_key = :name
    self.save_inventory_multi(:vdi_controllers, VdiController, ems, hashes, deletes, find_key, nil, [:vdi_farm, :vdi_desktops, :vdi_sessions])

    # Store the ids for the found records
    hashes.each do |h|
      ci = ems.vdi_controllers.detect { |r| r.send(find_key) == h[find_key] }
      h[:id] = ci.id
    end
  end

  def save_vdi_desktop_pools_inventory(ems, hashes, target = nil)
    return if hashes.nil?
    target = ems if target.nil?

    find_key = :name
    deletes = ems.vdi_desktop_pools(true).dup
    self.save_inventory_multi(:vdi_desktop_pools, VdiDesktopPool, ems, hashes, deletes, find_key, [:vdi_desktops], [:vdi_farm, :vdi_sessions, :folder, :vdi_users])

    # Link users to desktop pools
    hashes.each do |h|
      ci = ems.vdi_desktop_pools.detect { |r| r.send(find_key) == h[find_key] }
      h[:id] = ci.id
      unless h[:vdi_users].nil?
        user_ids = h[:vdi_users].collect {|u| u[:id]}
        users = VdiUser.find(:all, :select => "id", :conditions => ["id in (?)", user_ids])
        ci.vdi_users.replace(users)
      end

      # Set EMS relationships
      emses = ExtManagementSystem.find_all_by_ipaddress(h[:hosting_ipaddress].to_s.split(",").collect {|ip| ip.strip})
      ci.ext_management_systems.replace(emses)
    end
  end

  def save_vdi_desktops_inventory(desktop_group, hashes)
    return if hashes.nil?

    hashes.each do |h|
      # Find the VM that this Desktop is linked to
      h[:vm_or_template_id] = nil
      unless h[:vm_uid_ems].blank?
        v = VdiDesktop.find_vm_for_uid_ems(h)
        unless v.nil?
          h[:vm_or_template_id] = v.id
          v.update_attribute(:vdi, true) if v.vdi == false
        end
      end
    end

    find_key = :name
    deletes = desktop_group.vdi_desktops(true).dup
    self.save_inventory_multi(:vdi_desktops, VdiDesktop, desktop_group, hashes, deletes, find_key, :vdi_sessions, [:vdi_controller, :vdi_desktop_pool, :vdi_users])

    # Link users to desktops
    hashes.each do |h|
      ci = desktop_group.vdi_desktops.detect { |r| r.send(find_key) == h[find_key] }
      h[:id] = ci.id
      unless h[:vdi_users].nil?
        users = VdiUser.find_all_by_id(h[:vdi_users].collect {|u| u[:id]})
        ci.vdi_users.replace(users)
      end
    end
  end

  def save_vdi_sessions_inventory(vdi_desktop, hashes)
    return if hashes.nil?

    # Update the associated ids
    hashes.each { |h|
      h[:vdi_controller_id] = h.fetch_path(:vdi_controller, :id)
      h[:vdi_user_id] = h.fetch_path(:vdi_user, :id)
      # Do no remove an existing endpoint device from a session if no device information is passed.
      endpoint_id = h.fetch_path(:vdi_endpoint_device, :id)
      h[:vdi_endpoint_device_id] = endpoint_id unless endpoint_id.nil?
    }

    deletes = vdi_desktop.vdi_sessions(true).dup
    self.save_inventory_multi(:vdi_sessions, VdiSession, vdi_desktop, hashes, deletes, :uid_ems ,nil, [:vdi_controller, :vdi_desktop_pool, :vdi_desktop, :vdi_user, :vdi_endpoint_device])
  end

  def save_vdi_users_inventory(ems, hashes, target = nil)
    find_key = :uid_ems
    # FIXME: Could be replaced with link_habtm
    save_inventory_root_multi(:vdi_user, VdiUser, hashes, nil, find_key, nil, [:vdi_desktop_pools, :vdi_desktops, :vdi_sessions])

    # Store the ids for the found records
    vdi_users = VdiUser.all(:select => "id, uid_ems")
    hashes.each do |h|
      ci = vdi_users.detect { |r| r.send(find_key) == h[find_key] }
      h[:id] = ci.id
    end
  end

  def save_vdi_endpoint_devices_inventory(ems, hashes, target = nil)
    find_key = :uid_ems
    # FIXME: Could be replaced with link_habtm
    save_inventory_root_multi(:vdi_endpoint_device, VdiEndpointDevice, hashes, nil, find_key, nil, :vdi_sessions)

    # Store the ids for the found records
    endpoint_devices = VdiEndpointDevice.all(:select => "id, uid_ems")
    hashes.each do |h|
      ci = endpoint_devices.detect { |r| r.send(find_key) == h[find_key] }
      h[:id] = ci.id
    end
  end
end
