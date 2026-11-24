module EmsRefresh::SaveInventoryInfra
  def save_storages_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    deletes = determine_deletes_using_association(ems, target)

    save_inventory_multi(ems.storages, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.storages, hashes, :ems_ref)
  end

  def save_distributed_virtual_switches_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    deletes = determine_deletes_using_association(ems, target)

    save_inventory_multi(ems.distributed_virtual_switches, hashes, deletes, [:uid_ems], [:lans])
    store_ids_for_new_records(ems.distributed_virtual_switches, hashes, :uid_ems)
  end

  def save_host_storages_inventory(host, hashes, target = nil)
    target = host if target.nil?

    # Update the associated ids
    hashes.each do |h|
      h[:host_id]    = host.id
      h[:storage_id] = h.fetch_path(:storage, :id)
    end

    host.host_storages.reload
    deletes = if target == host
                host.host_storages.dup
              else
                []
              end

    save_inventory_multi(host.host_storages, hashes, deletes, [:host_id, :storage_id], nil, [:storage])
  end

  def save_folders_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.ems_folders.reset
    deletes = determine_deletes_using_association(ems, target)

    save_inventory_multi(ems.ems_folders, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.ems_folders, hashes, :uid_ems)
  end
  alias_method :save_ems_folders_inventory, :save_folders_inventory

  def save_clusters_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.ems_clusters.reset
    deletes = determine_deletes_using_association(ems, target)

    save_inventory_multi(ems.ems_clusters, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.ems_clusters, hashes, :uid_ems)
  end
  alias_method :save_ems_clusters_inventory, :save_clusters_inventory

  def save_resource_pools_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.resource_pools.reset
    deletes = if target == ems
                :use_association
              elsif target.kind_of?(Host)
                target.all_resource_pools_with_default
              else
                []
              end

    save_inventory_multi(ems.resource_pools, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.resource_pools, hashes, :uid_ems)
  end

  def save_storage_profiles_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.storage_profiles.reset
    deletes = determine_deletes_using_association(ems, target)

    save_inventory_multi(ems.storage_profiles, hashes, deletes, [:ems_ref], [:storage_profile_storages])
    store_ids_for_new_records(ems.storage_profiles, hashes, [:ems_ref])
  end

  def save_storage_profile_storages_inventory(storage_profile, storages)
    hashes = storages.collect do |storage|
      {
        :storage_profile_id => storage_profile.id,
        :storage_id         => storage[:id]
      }
    end

    save_inventory_multi(storage_profile.storage_profile_storages, hashes,
                         [], [:storage_profile_id, :storage_id])
  end

  def save_customization_specs_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    deletes = determine_deletes_using_association(ems, target)
    save_inventory_multi(ems.customization_specs, hashes, deletes, [:name])
  end

  def save_ems_extensions_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.ems_extensions.reset
    deletes = determine_deletes_using_association(ems, target)

    save_inventory_multi(ems.ems_extensions, hashes, deletes, [:ems_ref], nil)
    store_ids_for_new_records(ems.ems_extensions, hashes, :ems_ref)
  end

  def save_ems_licenses_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.ems_licenses.reset
    deletes = determine_deletes_using_association(ems, target)

    save_inventory_multi(ems.ems_licenses, hashes, deletes, [:ems_ref], nil)
    store_ids_for_new_records(ems.ems_licenses, hashes, :ems_ref)
  end

  def save_miq_scsi_targets_inventory(guest_device, hashes)
    save_inventory_multi(guest_device.miq_scsi_targets, hashes, :use_association, [:uid_ems], :miq_scsi_luns)
  end

  def save_miq_scsi_luns_inventory(miq_scsi_target, hashes)
    save_inventory_multi(miq_scsi_target.miq_scsi_luns, hashes, :use_association, [:uid_ems])
  end

  def save_switches_inventory(host, hashes)
    save_inventory_multi(host.host_virtual_switches, hashes, :use_association, [:uid_ems], [:lans])
    store_ids_for_new_records(host.host_virtual_switches, hashes, :uid_ems)
  end

  def save_host_switches_inventory(host, switches)
    hashes = switches.collect { |switch| {:host_id => host.id, :switch_id => switch[:id]} }
    save_inventory_multi(host.host_switches, hashes, [], [:host_id, :switch_id])
  end

  def save_lans_inventory(switch, hashes)
    extra_keys = [:parent]
    child_keys = [:subnets]

    save_inventory_multi(switch.lans, hashes, :use_association, [:uid_ems], child_keys, extra_keys)
    switch.save! # Needed to get ids back for lan new records

    store_ids_for_new_records(switch.lans, hashes, :uid_ems)

    child_lans = hashes.select { |h| !h[:id].nil? && !h.fetch_path(:parent, :id).nil? }
    child_lans.each do |h|
      parent_id = h.fetch_path(:parent, :id)
      Lan.where(:id => h[:id]).update_all(:parent_id => parent_id)
    end
  end

  def save_subnets_inventory(lan, hashes)
    save_inventory_multi(lan.subnets, hashes, :use_association, [:ems_ref])
  end

  def save_storage_files_inventory(storage, hashes)
    save_inventory_multi(storage.storage_files, hashes, :use_association, [:name])
  end
end
