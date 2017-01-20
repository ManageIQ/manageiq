#
# Calling order for EmsInfra:
# - ems
#   - storages
#   - storage_profiles
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
#   - orchestration_stacks
#   - orchestration_templates
#

module EmsRefresh::SaveInventoryInfra
  def save_ems_infra_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    # Check if the data coming in reflects a complete removal from the ems
    if hashes.blank? || (hashes[:hosts].blank? && hashes[:vms].blank? && hashes[:storages].blank?)
      target.disconnect_inv
      return
    end

    prev_relats = vmdb_relats(target)

    _log.info("#{log_header} Saving EMS Inventory...")
    if debug_trace
      require 'yaml'
      _log.debug "#{log_header} hashes:\n#{YAML.dump(hashes)}"
    end

    child_keys = [
      :storages,
      :storage_profiles,
      :clusters,
      :hosts,
      :vms,
      :folders,
      :resource_pools,
      :customization_specs,
      :orchestration_templates,
      :orchestration_stacks
    ]

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target)

    link_floating_ips_to_network_ports(hashes[:floating_ips]) if hashes.key?(:floating_ips)
    link_cloud_subnets_to_network_routers(hashes[:cloud_subnets]) if hashes.key?(:cloud_subnets)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Inventory...Complete")

    new_relats = hashes_relats(hashes)
    link_ems_inventory(ems, target, prev_relats, new_relats)
    remove_obsolete_switches

    ems
  end

  def save_storages_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    # Query for all of the storages ahead of time
    locs, names = hashes.partition { |h| h[:location] }
    locs.collect!  { |h| h[:location] }
    names.collect! { |h| h[:name] }
    locs  = Storage.where(:location => locs) unless locs.empty?
    names = Storage.where(:location => nil, :name => names) unless names.empty?

    hashes.each do |h|
      found = if h[:location]
                locs.detect { |s| s.location == h[:location] }
              else
                names.detect { |s| s.name == h[:name] }
              end

      if found.nil?
        _log.info("#{log_header} Creating Storage [#{h[:name]}] location: [#{h[:location]}]")
        found = Storage.create(h)
      else
        _log.info("#{log_header} Updating Storage [#{found.name}] id: [#{found.id}] location: [#{found.location}]")
        found.update_attributes!(h)
      end

      h[:id] = found.id
    end
  end

  def save_hosts_inventory(ems, hashes, target = nil)
    target = ems if target.nil?
    log_header = "EMS: [#{ems.name}], id: [#{ems.id}]"

    disconnects = if (target == ems)
                    target.hosts.reload.to_a
                  elsif target.kind_of?(Host)
                    [target.clone]
                  else
                    []
                  end

    child_keys = [:operating_system, :switches, :hardware, :system_services, :host_storages]
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

          found.update_attributes(h)
        end

        # Handle duplicate names coming in because of duplicate hostnames.
        begin
          found.save!
        rescue ActiveRecord::RecordInvalid
          raise if found.errors[:name].blank?
          old_name = Host.where("name LIKE ?", "#{found.name.sub(/ - \d+$/, "")}%").order("LENGTH(name) DESC").order("name DESC").first.name
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

  def save_host_storages_inventory(host, hashes, target = nil)
    target = host if target.nil?

    # Update the associated ids
    hashes.each do |h|
      h[:host_id]    = host.id
      h[:storage_id] = h.fetch_path(:storage, :id)
    end

    host.host_storages(true)
    deletes =
      if target == host
        host.host_storages.dup
      else
        []
      end

    save_inventory_multi(host.host_storages, hashes, deletes, [:host_id, :storage_id], nil, [:storage])
  end

  def save_folders_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.ems_folders.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.ems_folders, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.ems_folders, hashes, :uid_ems)
  end
  alias_method :save_ems_folders_inventory, :save_folders_inventory

  def save_clusters_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.ems_clusters.reset
    deletes = if (target == ems)
                :use_association
              else
                []
              end

    save_inventory_multi(ems.ems_clusters, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.ems_clusters, hashes, :uid_ems)
  end
  alias_method :save_ems_clusters_inventory, :save_clusters_inventory

  def save_resource_pools_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

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

  def save_storage_profiles_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.storage_profiles.reset
    deletes =
      if target == ems
        :use_association
      else
        []
      end

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

  def save_customization_specs_inventory(ems, hashes, _target = nil)
    save_inventory_multi(ems.customization_specs, hashes, :use_association, [:name])
  end

  def save_miq_scsi_targets_inventory(guest_device, hashes)
    save_inventory_multi(guest_device.miq_scsi_targets, hashes, :use_association, [:uid_ems], :miq_scsi_luns)
  end

  def save_miq_scsi_luns_inventory(miq_scsi_target, hashes)
    save_inventory_multi(miq_scsi_target.miq_scsi_luns, hashes, :use_association, [:uid_ems])
  end

  def save_switches_inventory(host, hashes)
    already_saved, not_yet_saved = hashes.partition { |h| h[:id] }
    save_inventory_multi(host.switches, not_yet_saved, [], [:uid_ems], :lans)
    host_switches_hash = already_saved.collect { |switch| {:host_id => host.id, :switch_id => switch[:id]} }
    save_inventory_multi(host.host_switches, host_switches_hash, [], [:host_id, :switch_id])
    host.switches(true)

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

    # handle deletes here instead of inside #save_inventory_multi
    switch_ids = Set.new(hashes.collect { |s| s[:id] })
    deletes = host.switches.select { |s| !switch_ids.include?(s.id) }
    host.switches.delete(deletes)
  end

  def remove_obsolete_switches
    # delete from switches as s where s.shared is NULL and s.id not in (select switch_id from host_switches)
    # delete from switches as s where s.shared = 't' and s.id not in (select switch_id from host_switches)
    Switch.where.not(:id => HostSwitch.all.collect(&:switch).uniq).destroy_all
  end

  def save_lans_inventory(switch, hashes)
    save_inventory_multi(switch.lans, hashes, :use_association, [:uid_ems])
  end

  def save_storage_files_inventory(storage, hashes)
    save_inventory_multi(storage.storage_files, hashes, :use_association, [:name])
  end

  def find_host(h, ems_id)
    found = nil
    if h[:ems_ref]
      _log.debug "EMS ID: #{ems_id} Host database lookup - ems_ref: [#{h[:ems_ref]}] ems_id: [#{ems_id}]"
      found = Host.find_by(:ems_ref => h[:ems_ref], :ems_id => ems_id)
    end

    if found.nil?
      if h[:hostname].nil? && h[:ipaddress].nil?
        _log.debug "EMS ID: #{ems_id} Host database lookup - name [#{h[:name]}]"
        found = Host.where(:ems_id => ems_id).detect { |e| e.name.downcase == h[:name].downcase }
      elsif ["localhost", "localhost.localdomain", "127.0.0.1"].include_none?(h[:hostname], h[:ipaddress])
        # host = Host.find_by_hostname(hostname) has a risk of creating duplicate hosts
        # allow a deleted EMS to be re-added an pick up old orphaned hosts
        _log.debug "EMS ID: #{ems_id} Host database lookup - hostname: [#{h[:hostname]}] IP: [#{h[:ipaddress]}] ems_ref: [#{h[:ems_ref]}]"
        found = look_up_host(h[:hostname], h[:ipaddress], :ems_ref => h[:ems_ref])
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
    if (opts[:ems_ref] && h.ems_ref != opts[:ems_ref]) || (opts[:ems_id] && h.ems_id != opts[:ems_id])
      h = nil
    end unless h.nil?

    h
  end
end
