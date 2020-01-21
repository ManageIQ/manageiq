#
# Calling order for EmsInfra:
# - ems
#   - storages
#   - storage_profiles
#   - distributed_virtual_switches
#     - lans
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
#     - host_storages
#     - host_switches
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
#   - ems_extensions
#   - ems_licenses
#
#   - link
#   - orchestration_stacks
#   - orchestration_templates
#

module EmsRefresh::SaveInventoryInfra
  def save_ems_infra_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes_of_target_empty?(hashes, target)
      target.disconnect_inv if disconnect
      return
    end

    prev_relats = vmdb_relats(target)

    _log.info("#{log_header} Saving EMS Inventory...")
    if debug_trace
      require 'yaml'
      _log.debug("#{log_header} hashes:\n#{YAML.dump(hashes)}")
    end

    child_keys = [
      :storages,
      :storage_profiles,
      :distributed_virtual_switches,
      :clusters,
      :hosts,
      :vms,
      :folders,
      :resource_pools,
      :customization_specs,
      :ems_extensions,
      :ems_licenses,
      :orchestration_templates,
      :orchestration_stacks
    ]

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target, disconnect)

    link_floating_ips_to_network_ports(hashes[:floating_ips]) if hashes.key?(:floating_ips)
    link_cloud_subnets_to_network_routers(hashes[:cloud_subnets]) if hashes.key?(:cloud_subnets)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Inventory...Complete")

    new_relats = hashes_relats(hashes)
    link_ems_inventory(ems, target, prev_relats, new_relats, disconnect)

    ems
  end

  def save_storages_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?
    deletes = determine_deletes_using_association(ems, target, disconnect)

    save_inventory_multi(ems.storages, hashes, deletes, [:ems_ref])
    store_ids_for_new_records(ems.storages, hashes, :ems_ref)
  end

  def save_distributed_virtual_switches_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?
    deletes = determine_deletes_using_association(ems, target, disconnect)

    save_inventory_multi(ems.distributed_virtual_switches, hashes, deletes, [:uid_ems], [:lans])
    store_ids_for_new_records(ems.distributed_virtual_switches, hashes, :uid_ems)
  end

  def save_hosts_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil? && disconnect
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    disconnects = if (target == ems)
                    target.hosts.reload.to_a
                  elsif target.kind_of?(Host)
                    [target.clone]
                  else
                    []
                  end

    child_keys = [:operating_system, :switches, :hardware, :system_services, :host_storages, :host_switches]
    extra_keys = [:ems_cluster, :storages, :vms, :power_state, :ems_children]
    remove_keys = child_keys + extra_keys

    invalids_found = false
    hashes.each do |h|
      # Backup keys that cannot be written directly to the database
      key_backup = backup_keys(h, remove_keys)

      h[:ems_cluster_id] = key_backup.fetch_path(:ems_cluster, :id)

      begin
        raise MiqException::MiqIncompleteData if h[:invalid]

        found = find_host(h, ems.id)

        if found.nil?
          _log.info("#{log_header} Creating Host [#{h[:name]}] hostname: [#{h[:hostname]}] IP: [#{h[:ipaddress]}] ems_ref: [#{h[:ems_ref]}]")
          found = ems.hosts.build(h)
        else
          _log.info("#{log_header} Updating Host [#{found.name}] id: [#{found.id}] hostname: [#{found.hostname}] IP: [#{found.ipaddress}] ems_ref: [#{h[:ems_ref]}]")
          h[:ems_id] = ems.id  # Steal this host from the previous EMS

          # Adjust the names so they do not keep changing in the event of DNS problems
          ip_part  =  /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/
          ip_whole = /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/

          # Keep the previous ip address if we don't have a new one or the new one is not an ip address
          h[:ipaddress] = found.ipaddress if h[:ipaddress].nil? || (h[:ipaddress] !~ ip_whole)

          #   Keep the previous hostname unless it's nil or it's an ip address
          h[:hostname] = found.hostname unless found.hostname.nil? || (found.hostname =~ ip_whole)

          if found.name =~ /#{h[:name]} - \d+$/
            # Update the name to be found.name if it has the same ems_ref and the name
            # already has a '- int' suffix to work around duplicate hostnames
            h[:name] = found.name
          elsif h[:name] =~ ip_part && h[:hostname] !~ ip_whole
            # Update the name to the hostname if the new name has an ip address,
            # and the new hostname is not an ip address
            h[:name] = h[:hostname]
          end

          h.delete(:type)

          found.update(h)
        end

        found.save!

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
        if err.kind_of?(MiqException::MiqIncompleteData)
          _log.warn("#{log_header} Processing Host: [#{name}] failed with error [#{err.class}: #{err}]. Skipping Host.")
        else
          raise if EmsRefresh.debug_failures
          _log.error("#{log_header} Processing Host: [#{name}] failed with error [#{err.class}: #{err}]. Skipping Host.")
          _log.log_backtrace(err)
        end
      ensure
        restore_keys(h, remove_keys, key_backup)
      end
    end

    unless disconnects.empty?
      if invalids_found
        _log.warn("#{log_header} Since failures occurred, not disconnecting for Hosts #{log_format_deletes(disconnects)}")
      else
        _log.info("#{log_header} Disconnecting Hosts #{log_format_deletes(disconnects)}")
        disconnects.each(&:disconnect_inv)
      end
    end
  end

  def save_host_storages_inventory(host, hashes, target = nil, disconnect = true)
    target = host if target.nil?

    # Update the associated ids
    hashes.each do |h|
      h[:host_id]    = host.id
      h[:storage_id] = h.fetch_path(:storage, :id)
    end

    host.host_storages.reload
    deletes = if disconnect && target == host
                host.host_storages.dup
              else
                []
              end

    save_inventory_multi(host.host_storages, hashes, deletes, [:host_id, :storage_id], nil, [:storage])
  end

  def save_folders_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?

    ems.ems_folders.reset
    deletes = determine_deletes_using_association(ems, target, disconnect)

    save_inventory_multi(ems.ems_folders, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.ems_folders, hashes, :uid_ems)
  end
  alias_method :save_ems_folders_inventory, :save_folders_inventory

  def save_clusters_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?

    ems.ems_clusters.reset
    deletes = determine_deletes_using_association(ems, target, disconnect)

    save_inventory_multi(ems.ems_clusters, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.ems_clusters, hashes, :uid_ems)
  end
  alias_method :save_ems_clusters_inventory, :save_clusters_inventory

  def save_resource_pools_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil? && disconnect

    ems.resource_pools.reset
    deletes = if (target == ems)
                :use_association
              elsif target.kind_of?(Host)
                target.all_resource_pools_with_default
              else
                []
              end

    save_inventory_multi(ems.resource_pools, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.resource_pools, hashes, :uid_ems)
  end

  def save_storage_profiles_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?

    ems.storage_profiles.reset
    deletes = determine_deletes_using_association(ems, target, disconnect)

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

  def save_customization_specs_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?

    deletes = determine_deletes_using_association(ems, target, disconnect)
    save_inventory_multi(ems.customization_specs, hashes, deletes, [:name])
  end

  def save_ems_extensions_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?

    ems.ems_extensions.reset
    deletes = determine_deletes_using_association(ems, target, disconnect)

    save_inventory_multi(ems.ems_extensions, hashes, deletes, [:ems_ref], nil)
    store_ids_for_new_records(ems.ems_extensions, hashes, :ems_ref)
  end

  def save_ems_licenses_inventory(ems, hashes, target = nil, disconnect = true)
    target = ems if target.nil?

    ems.ems_licenses.reset
    deletes = determine_deletes_using_association(ems, target, disconnect)

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

  def find_host(h, ems_id)
    found = nil
    if h[:ems_ref]
      _log.debug("EMS ID: #{ems_id} Host database lookup - ems_ref: [#{h[:ems_ref]}] ems_id: [#{ems_id}]")
      found = Host.find_by(:ems_ref => h[:ems_ref], :ems_id => ems_id)
    end

    if found.nil?
      if h[:hostname].nil? && h[:ipaddress].nil?
        _log.debug("EMS ID: #{ems_id} Host database lookup - name [#{h[:name]}]")
        found = Host.where(:ems_id => ems_id).detect { |e| e.name.downcase == h[:name].downcase }
      elsif ["localhost", "localhost.localdomain", "127.0.0.1"].include_none?(h[:hostname], h[:ipaddress])
        # host = Host.find_by_hostname(hostname) has a risk of creating duplicate hosts
        # allow a deleted EMS to be re-added an pick up old orphaned hosts
        _log.debug("EMS ID: #{ems_id} Host database lookup - hostname: [#{h[:hostname]}] IP: [#{h[:ipaddress]}] ems_ref: [#{h[:ems_ref]}]")
        found = look_up_host(h[:hostname], h[:ipaddress], :ems_id => ems_id)
      end
    end

    found
  end

  def look_up_host(hostname, ipaddr, opts = {})
    h   = Host.where("lower(hostname) = ?", hostname.downcase).find_by(:ipaddress => ipaddr) if hostname && ipaddr
    h ||= Host.find_by("lower(hostname) = ?", hostname.downcase)                             if hostname
    h ||= Host.find_by(:ipaddress => ipaddr)                                                 if ipaddr
    h ||= Host.find_by("lower(hostname) LIKE ?", "#{hostname.downcase}.%")                   if hostname

    # If we're given an ems_ref or ems_id then ensure that the host
    # we looked-up does not have a different ems_ref and is not
    # owned by another provider, this would cause us to overwrite
    # a different host record
    if (opts[:ems_ref] && h.ems_ref != opts[:ems_ref]) || (opts[:ems_id] && h.ems_id && h.ems_id != opts[:ems_id])
      h = nil
    end unless h.nil?

    h
  end
end
