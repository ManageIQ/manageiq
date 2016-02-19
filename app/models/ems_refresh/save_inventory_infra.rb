#
# Calling order for EmsInfra:
# - ems
#   - storages
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

    child_keys = [:storages, :clusters, :hosts, :vms, :folders, :resource_pools, :customization_specs,
                  :orchestration_templates, :orchestration_stacks, :cloud_networks, :security_groups, :floating_ips,
                  :network_routers, :network_ports]

    # Save and link other subsections
    save_child_inventory(ems, hashes, child_keys, target)

    link_floating_ips_to_network_ports(hashes[:floating_ips]) if hashes.key?(:floating_ips)
    link_cloud_subnets_to_network_routers(hashes[:cloud_subnets]) if hashes.key?(:cloud_subnets)

    ems.save!
    hashes[:id] = ems.id

    _log.info("#{log_header} Saving EMS Inventory...Complete")

    new_relats = hashes_relats(hashes)
    link_ems_inventory(ems, target, prev_relats, new_relats)

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
                    target.hosts(true).to_a.dup
                  elsif target.kind_of?(Host)
                    [target.clone]
                  else
                    []
                  end

    child_keys = [:operating_system, :switches, :hardware, :system_services]
    extra_keys = [:ems_cluster, :storages, :vms, :power_state, :ems_children]
    remove_keys = child_keys + extra_keys

    invalids_found = false
    hashes.each do |h|
      # Backup keys that cannot be written directly to the database
      key_backup = backup_keys(h, remove_keys)

      h[:ems_cluster_id] = key_backup.fetch_path(:ems_cluster, :id)

      begin
        raise MiqException::MiqIncompleteData if h[:invalid]

        # Find this host record
        found = nil
        if h[:ems_ref]
          _log.debug "#{log_header} Host database lookup - ems_ref: [#{h[:ems_ref]}] ems_id: [#{ems.id}]"
          found = Host.find_by(:ems_ref => h[:ems_ref], :ems_id => ems.id)
        end

        if found.nil?
          if h[:hostname].nil? && h[:ipaddress].nil?
            _log.debug "#{log_header} Host database lookup - name [#{h[:name]}]"
            found = ems.hosts.detect { |e| e.name.downcase == h[:name].downcase }
          elsif ["localhost", "localhost.localdomain", "127.0.0.1"].include_none?(h[:hostname], h[:ipaddress])
            # host = Host.find_by_hostname(hostname) has a risk of creating duplicate hosts
            # allow a deleted EMS to be re-added an pick up old orphaned hosts
            _log.debug "#{log_header} Host database lookup - hostname: [#{h[:hostname]}] IP: [#{h[:ipaddress]}] ems_ref: [#{h[:ems_ref]}]"
            found = Host.lookUpHost(h[:hostname], h[:ipaddress], :ems_ref => h[:ems_ref])
          end
        end

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

          #   Update the name to the hostname if the new name has an ip address,
          #   and the new hostname is not an ip address
          h[:name] = h[:hostname] if h[:name] =~ ip_part && !(h[:hostname] =~ ip_whole)

          h.delete(:type)

          found.update_attributes(h)
        end

        # Handle duplicate names coming in because of duplicate hostnames.
        begin
          found.save!
        rescue ActiveRecord::RecordInvalid
          raise if found.errors[:name].blank?
          old_name = Host.where("name LIKE ?", "#{found.name.sub(/ - \d+$/, "")}%").order("name DESC").first.name
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
        h[:_object] = found
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

  def save_folders_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.ems_folders(true)
    deletes = if (target == ems)
                ems.ems_folders.dup
              else
                []
              end

    save_inventory_multi(ems.ems_folders, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.ems_folders, hashes, :uid_ems)
  end
  alias_method :save_ems_folders_inventory, :save_folders_inventory

  def save_clusters_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.ems_clusters(true)
    deletes = if (target == ems)
                ems.ems_clusters.dup
              else
                []
              end

    save_inventory_multi(ems.ems_clusters, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.ems_clusters, hashes, :uid_ems)
  end
  alias_method :save_ems_clusters_inventory, :save_clusters_inventory

  def save_resource_pools_inventory(ems, hashes, target = nil)
    target = ems if target.nil?

    ems.resource_pools(true)
    deletes = if (target == ems)
                ems.resource_pools.dup
              elsif target.kind_of?(Host)
                target.all_resource_pools_with_default.dup
              else
                []
              end

    save_inventory_multi(ems.resource_pools, hashes, deletes, [:uid_ems], nil, :ems_children)
    store_ids_for_new_records(ems.resource_pools, hashes, :uid_ems)
  end

  def save_customization_specs_inventory(ems, hashes, _target = nil)
    deletes = ems.customization_specs(true).dup
    save_inventory_multi(ems.customization_specs, hashes, deletes, [:name])
  end

  def save_miq_scsi_targets_inventory(guest_device, hashes)
    deletes = guest_device.miq_scsi_targets(true).dup
    save_inventory_multi(guest_device.miq_scsi_targets, hashes, deletes, [:uid_ems], :miq_scsi_luns)
  end

  def save_miq_scsi_luns_inventory(miq_scsi_target, hashes)
    deletes = miq_scsi_target.miq_scsi_luns(true).dup
    save_inventory_multi(miq_scsi_target.miq_scsi_luns, hashes, deletes, [:uid_ems])
  end

  def save_switches_inventory(host, hashes)
    deletes = host.switches(true).dup
    save_inventory_multi(host.switches, hashes, deletes, [:uid_ems], :lans)

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
  end

  def save_lans_inventory(switch, hashes)
    deletes = switch.lans(true).dup
    save_inventory_multi(switch.lans, hashes, deletes, [:uid_ems])
  end

  def save_storage_files_inventory(storage, hashes)
    deletes = storage.storage_files(true).dup
    save_inventory_multi(storage.storage_files, hashes, deletes, [:name])
  end
end
