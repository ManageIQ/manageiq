#
# Calling order for EmsPhysicalInfra:
# - ems
#   - physical_racks
#   - physical_chassis
#   - physical_storages
#   - physical_servers
#   - physical_switches
#

module EmsRefresh::SaveInventoryPhysicalInfra
  def save_ems_physical_infra_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes.blank?
      target.disconnect_inv
      return
    end

    _log.info("#{log_header} Saving EMS Inventory...")
    if debug_trace
      require 'yaml'
      _log.debug("#{log_header} hashes:\n#{YAML.dump(hashes)}")
    end

    child_keys = %i(physical_racks physical_chassis physical_storages physical_servers physical_switches customization_scripts)

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Inventory...Complete")

    ems
  end

  def save_physical_racks_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    deletes = target == ems ? :use_association : []

    save_inventory_multi(ems.physical_racks, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.physical_racks, hashes, :ems_ref)
  end

  def save_physical_switches_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    deletes = target == ems ? :use_association : []

    save_inventory_multi(ems.physical_switches, hashes, deletes, [:uid_ems], %i(asset_detail hardware physical_network_ports))
  end

  def save_physical_servers_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    deletes = target == ems ? :use_association : []

    child_keys = %i(computer_system asset_detail hosts)
    hashes.each do |h|
      h[:physical_rack_id] = h.delete(:physical_rack).try(:[], :id)
      h[:physical_chassis_id] = h.delete(:physical_chassis).try(:[], :id)
    end

    save_inventory_multi(ems.physical_servers, hashes, deletes, [:ems_ref], child_keys)
    store_ids_for_new_records(ems.physical_servers, hashes, :ems_ref)
  end

  def save_customization_scripts_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    deletes = target == ems ? :use_association : []

    save_inventory_multi(ems.customization_scripts, hashes, deletes, [:manager_ref])
    store_ids_for_new_records(ems.customization_scripts, hashes, :manager_ref)
  end

  def save_physical_chassis_inventory(ems, hashes, target = nil)
    target ||= ems
    deletes = target == ems ? :use_association : []

    hashes.each do |h|
      h[:physical_rack_id] = h.delete(:physical_rack).try(:[], :id)
    end

    child_keys = %i(computer_system asset_detail)
    save_inventory_multi(ems.physical_chassis, hashes, deletes, [:ems_ref], child_keys)
    store_ids_for_new_records(ems.physical_chassis, hashes, :ems_ref)
  end

  def save_physical_storages_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    deletes = target == ems ? :use_association : []

    hashes.each do |h|
      h[:physical_rack_id] = h.delete(:physical_rack).try(:[], :id)
      h[:physical_chassis_id] = h.delete(:physical_chassis).try(:[], :id)
    end

    child_keys = %i(computer_system asset_detail physical_disk)
    save_inventory_multi(ems.physical_storages, hashes, deletes, [:ems_ref], child_keys)
    store_ids_for_new_records(ems.physical_storages, hashes, :ems_ref)
  end

  #
  # Saves asset details information of a resource
  #
  def save_asset_detail_inventory(parent, hash)
    return if hash.nil?
    save_inventory_single(:asset_detail, parent, hash)
  end

  #
  # Saves the drive information of a storage
  #
  def save_physical_disk_inventory(parent, hash)
    return if hash.nil?
    save_inventory_single(:physical_disk, parent, hash)
  end

  def save_physical_network_ports_inventory(guest_device, hashes, target = nil)
    return if hashes.nil?

    deletes = target == guest_device ? :use_association : []

    find_keys = %i(port_type uid_ems)

    save_inventory_multi(guest_device.physical_network_ports, hashes, deletes, find_keys)
  end
end
