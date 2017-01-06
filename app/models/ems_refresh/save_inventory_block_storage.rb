#
# Calling order for EmsCloud
# - ems
#   - cloud_volumes
#   - cloud_volume_backups
#   - cloud_volume_snapshots
#   - backing_links
#

module EmsRefresh::SaveInventoryBlockStorage
  def save_ems_block_storage_inventory(ems, hashes, target = nil)
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
      :backing_links
    ]

    # Save and link other subsections
    save_block_storage_child_inventory(ems, hashes, child_keys, target)

    link_block_storage_volumes_to_base_snapshots(hashes[:cloud_volumes]) if hashes.key?(:cloud_volumes)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Inventory...Complete")

    ems
  end

  def save_block_storage_cloud_volumes_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_volumes.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id] = ems.id
      # Defer setting :cloud_volume_snapshot_id until after snapshots are saved.
    end

    save_inventory_multi(ems.cloud_volumes, hashes, deletes, [:ems_ref],
                         nil, [:tenant, :availability_zone, :base_snapshot])
    store_ids_for_new_records(ems.cloud_volumes, hashes, :ems_ref)
  end

  def save_block_storage_cloud_volume_backups_inventory(ems, hashes, target = nil)
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
    end

    save_inventory_multi(ems.cloud_volume_backups, hashes, deletes, [:ems_ref], nil,
                         [:tenant, :volume, :availability_zone])
    store_ids_for_new_records(ems.cloud_volume_backups, hashes, :ems_ref)
  end

  def save_block_storage_cloud_volume_snapshots_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_volume_snapshots.reset
    deletes = if target == ems
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id]          = ems.id
      h[:cloud_volume_id] = h.fetch_path(:volume, :id)
    end

    save_inventory_multi(ems.cloud_volume_snapshots, hashes, deletes, [:ems_ref], nil, [:tenant, :volume])
    store_ids_for_new_records(ems.cloud_volume_snapshots, hashes, :ems_ref)
  end

  def save_block_storage_backing_links_inventory(_ems, hashes, _target)
    hashes.each do |dh|
      dh[:backing_id]   = dh[:backing_volume][:id]
      dh[:backing_type] = 'CloudVolume'

      # Existing disk, update attributes.
      if dh.key?(:id)
        unless (disk = Disk.where(:id => dh[:id]).first)
          _log.warn "Expected disk not found, id = #{dh[:id]}"
          next
        end
        disk.update(dh.except(:id, :backing_volume))
        next
      end

      # New disk, create entry.
      Disk.create(dh.except(:backing_volume))
    end
  end

  def link_block_storage_volumes_to_base_snapshots(hashes)
    base_snapshot_to_volume = hashes.each_with_object({}) do |h, bsh|
      next unless (base_snapshot = h[:base_snapshot])
      (bsh[base_snapshot[:id]] ||= []) << h[:id]
    end

    base_snapshot_to_volume.each do |bsid, volids|
      CloudVolume.where(:id => volids).update_all(:cloud_volume_snapshot_id => bsid)
    end
  end

  def save_block_storage_child_inventory(obj, hashes, child_keys, *args)
    child_keys.each { |k| send("save_block_storage_#{k}_inventory", obj, hashes[k], *args) if hashes.key?(k) }
  end
end
