#
# Calling order for EmsCloud
# - ems
#   - cloud_volumes
#   - cloud_volume_backups
#   - cloud_volume_snapshots
#   - vms
#     - storages (link)
#     - security_groups (link)
#     - operating_system
#     - hardware
#       - disks
#       - guest_devices
#     - custom_attributes
#     - snapshots
#

module EmsRefresh::SaveInventoryCinder
  def save_ems_cinder_inventory(ems, hashes, target = nil)
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
      _log.debug "#{log_header} hashes:\n#{YAML.dump(hashes)}"
    end

    child_keys = [
      :cloud_volumes,
      :cloud_volume_backups,
      :cloud_volume_snapshots,
      :vms,
    ]

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target)

    link_volumes_to_base_snapshots(hashes[:cloud_volumes]) if hashes.key?(:cloud_volumes)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Inventory...Complete")

    ems
  end

  def save_cloud_volumes_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_volumes.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id]               = ems.id
      h[:cloud_tenant_id]      = h.fetch_path(:tenant, :id)
      h[:availability_zone_id] = h.fetch_path(:availability_zone, :id)
      # Defer setting :cloud_volume_snapshot_id until after snapshots are saved.
    end

    save_inventory_multi(ems.cloud_volumes, hashes, deletes, [:ems_ref], nil, [:tenant, :availability_zone, :base_snapshot])
    store_ids_for_new_records(ems.cloud_volumes, hashes, :ems_ref)
  end

  def save_cloud_volume_backups_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_volume_backups.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id]          = ems.id
      h[:cloud_volume_id] = h.fetch_path(:volume, :id)
      h[:availability_zone_id] = h.fetch_path(:availability_zone, :id)
    end

    save_inventory_multi(ems.cloud_volume_backups, hashes, deletes, [:ems_ref], nil,
                         [:tenant, :volume, :availability_zone])
    store_ids_for_new_records(ems.cloud_volume_backups, hashes, :ems_ref)
  end

  def save_cloud_volume_snapshots_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_volume_snapshots.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id]          = ems.id
      h[:cloud_tenant_id] = h.fetch_path(:tenant, :id)
      h[:cloud_volume_id] = h.fetch_path(:volume, :id)
    end

    save_inventory_multi(ems.cloud_volume_snapshots, hashes, deletes, [:ems_ref], nil, [:tenant, :volume])
    store_ids_for_new_records(ems.cloud_volume_snapshots, hashes, :ems_ref)
  end

  def link_volumes_to_base_snapshots(hashes)
    base_snapshot_to_volume = hashes.each_with_object({}) do |h, bsh|
      next unless (base_snapshot = h[:base_snapshot])
      (bsh[base_snapshot[:id]] ||= []) << h[:id]
    end

    base_snapshot_to_volume.each do |bsid, volids|
      CloudVolume.where(:id => volids).update_all(:cloud_volume_snapshot_id => bsid)
    end
  end


end
