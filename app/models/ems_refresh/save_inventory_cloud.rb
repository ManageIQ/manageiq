#
# Calling order for EmsCloud
# - ems
#   - flavors
#   - availability_zones
#   - cloud_tenants
#   - key_pairs
#   - orchestration_templates
#   - orchestration_stacks
#   - security_groups
#     - firewall_rules
#   - cloud_volumes
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
#   - cloud_object_store_containers
#     - cloud_object_store_objects
#

module EmsRefresh::SaveInventoryCloud
  def save_ems_cloud_inventory(ems, hashes, target = nil)
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
      :flavors,
      :availability_zones,
      :cloud_tenants,
      :key_pairs,
      :orchestration_templates,
      :orchestration_stacks,
      # TODO(lsmola) NetworkManager, once all providers are converted :cloud_networks and :security_groups will go away
      :cloud_networks,
      :security_groups,
      :cloud_volumes,
      :cloud_volume_snapshots,
      :vms,
      # TODO(lsmola) NetworkManager, once all providers are converted :floating_ips will go away
      :floating_ips,
      :cloud_resource_quotas,
      :cloud_object_store_containers,
      :cloud_object_store_objects,
      :resource_groups
    ]

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target)

    link_volumes_to_base_snapshots(hashes[:cloud_volumes]) if hashes.key?(:cloud_volumes)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Inventory...Complete")

    ems
  end

  def save_flavors_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.flavors.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.flavors, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.flavors, hashes, :ems_ref)
  end

  def save_availability_zones_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.availability_zones.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.availability_zones, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.availability_zones, hashes, :ems_ref)
  end

  def save_cloud_tenants_inventory(ems, hashes, target = nil)
    target ||= ems

    ems.cloud_tenants.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.cloud_tenants, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.cloud_tenants, hashes, :ems_ref)
  end

  def save_cloud_resource_quotas_inventory(ems, hashes, target = nil)
    target ||= ems

    ems.cloud_resource_quotas.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:cloud_tenant_id] = h.fetch_path(:cloud_tenant, :id)
    end

    save_inventory_multi(ems.cloud_resource_quotas, hashes, deletes, [:ems_ref, :name], nil, :cloud_tenant)
    store_ids_for_new_records(ems.cloud_resource_quotas, hashes, [:ems_ref, :name])
  end

  def save_key_pairs_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.key_pairs.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.key_pairs, hashes, deletes, [:name])
    store_ids_for_new_records(ems.key_pairs, hashes, :name)
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

  def save_cloud_object_store_containers_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_object_store_containers.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id]          = ems.id
      h[:cloud_tenant_id] = h.fetch_path(:tenant, :id)
    end

    save_inventory_multi(ems.cloud_object_store_containers, hashes, deletes, [:ems_ref], nil, :tenant)
    store_ids_for_new_records(ems.cloud_object_store_containers, hashes, :ems_ref)
  end

  def save_cloud_object_store_objects_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.cloud_object_store_objects.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    hashes.each do |h|
      h[:ems_id]                          = ems.id
      h[:cloud_tenant_id]                 = h.fetch_path(:tenant, :id)
      h[:cloud_object_store_container_id] = h.fetch_path(:container, :id)
    end

    save_inventory_multi(ems.cloud_object_store_objects, hashes, deletes, [:ems_ref], nil, [:tenant, :container])
    store_ids_for_new_records(ems.cloud_object_store_objects, hashes, :ems_ref)
  end

  def save_resource_groups_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.resource_groups.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.resource_groups, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.resource_groups, hashes, :ems_ref)
  end
end
