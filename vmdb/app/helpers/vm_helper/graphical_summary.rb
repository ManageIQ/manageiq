module VmHelper::GraphicalSummary
  # TODO: Verify why there are onclick events with miqCheckForChanges(), but only on some links.

  #
  # Groups
  #

  def graphical_group_properties
    items = %w{container osinfo smart power_state snapshots compliance_status compliance_history}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_lifecycle
    items = %w{discovered analyzed retirement_date}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_relationships
    items = %w{ems cluster host resource_pool storage service parent_vm genealogy drift scan_history vdi_desktop}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_vm_cloud_relationships
    items = %w{availability_zone flavor drift scan_history}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_template_cloud_relationships
    items = %w{drift scan_history}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_security
    items = %w{users groups patches}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_configuration
    items = %w{guest_applications init_processes win32_services kernel_drivers filesystem_drivers filesystems registry_items disks advanced_settings}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_diagnostics
    items = %w{processes event_logs}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_storage_relationships
    items = %w{storage_systems storage_volumes logical_disks file_shares}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_container
    h = {:label => "Container"}
    vendor = @record.vendor
    if vendor.blank?
      h[:value] = "None"
    else
      h[:image] = vendor.downcase
      h[:value] = "#{vendor} (#{pluralize(@record.num_cpu, 'CPU')}, #{@record.mem_cpu} MB)"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'hv_info'}, :remote => @explorer, :title => "Show VMM container information")
    end
    h
  end

  def graphical_osinfo
    h = {:label => "OS", :image => @record.os_image_name.downcase}
    os = @record.operating_system.nil? ? nil : @record.operating_system.product_name
    if os.blank?
      h[:value] = "Unknown"
    else
      h[:value] = os.truncate(20)
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'os_info'}, :remote => @explorer, :title => "Show VM OS information '#{os}'")
    end
    h
  end

  def graphical_smart
    @record.smart? ? {:label => "Smart", :image => "smart"} : nil
  end

  def graphical_power_state
    state = @record.current_state.to_s.downcase
    state = "unknown" if state.blank?
    h = {:label => "Power State", :value => state}
    h[:image] = @record.template? ? (@record.host ? "template" : "template-no-host") : state
    h
  end

  def graphical_snapshots
    h = {:label => "Snapshots", :value => @record.number_of(:snapshots), :image => "snapshot"}
    if role_allows(:feature => "vm_snapshot_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'snapshot_info'}, :remote => @explorer, :title => "Show virtual machine snapshot information")
    end
    h
  end

  def graphical_compliance_status
    h = {:image => "compliance"}
    if @record.number_of(:compliances) == 0
      h[:label] = "Compliance Status"
      h[:value] = "Never Verified"
    else
      h[:label] = "#{"Non-" unless @record.last_compliance_status}Compliance Status"
      h[:value] = "#{time_ago_in_words(@record.last_compliance.timestamp.in_time_zone(Time.zone)).titleize} Ago"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'compliance_history'}, :remote => @explorer, :title => "Show Compliance History of this VM (Last 10 Checks)")
    end
    h
  end

  def graphical_compliance_history
    h = {:image => "compliance_history"}
    if @record.number_of(:compliances) == 0
      h[:label] = "Compliance History"
      h[:value] = "Not Available"
    else
      h[:label] = "#{"Non-" unless @record.last_compliance_status}Compliance History"
      h[:value] = "Available"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'compliance_history'}, :remote => @explorer, :title => "Show Compliance History of this VM (Last 10 Checks)")
    end
    h
  end

  def graphical_discovered
    {:label => "Discovered", :image => "discovered", :value => "#{time_ago_in_words(@record.created_on.in_time_zone(Time.zone)).titleize} Ago"}
  end

  def graphical_analyzed
    h = {:label => "Analyzed", :image => "extract"}
    h[:value] = @record.last_sync_on.nil? ? "Never" : "#{time_ago_in_words(@record.last_sync_on.in_time_zone(Time.zone)).titleize} Ago"
    h
  end

  def graphical_retirement_date
    {:label => "Retirement Date", :image => "retirement_date", :value => (@record.retires_on.nil? ? "Never" : @record.retires_on.to_time.strftime("%x"))}
  end

  def graphical_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_infra")
    h = {:label => label, :image => ems.emstype, :value => ems.name.truncate(13)}
    if role_allows(:feature => "ems_infra_show")
      h[:link] = link_to("", {:controller => 'ems_infra', :action => 'show', :id => ems}, :title => "Show parent #{label} '#{ems.name}'")
    end
    h
  end

  def graphical_cluster
    cluster = @record.ems_cluster
    h = {:label => "Cluster", :image => "ems_cluster", :value => (cluster.nil? ? "None" : cluster.name.truncate(13))}
    if cluster && role_allows(:feature => "ems_cluster_show")
      h[:link] = link_to("", {:controller => 'ems_cluster', :action => 'show', :id => cluster}, :title => "Show Cluster '#{cluster.name}'")
    end
    h
  end

  def graphical_host
    host = @record.host
    h = {:label => "Host", :image => "host", :value => (host.nil? ? "None" : host.name.truncate(13))}
    if host && role_allows(:feature => "host_show")
      h[:link] = link_to("", {:controller => 'host', :action => 'show', :id => host}, :title => "Show Host '#{host.name}'")
    end
    h
  end

  def graphical_resource_pool
    rp = @record.parent_resource_pool
    # TODO: Why doesn't this image match the one in textual?
    h = {:label => "Resource Pool", :image => "resource_pool", :value => (rp.nil? ? "None" : rp.name.truncate(13))}
    if rp && role_allows(:feature => "resource_pool_show")
      h[:link] = link_to("", {:controller => 'resource_pool', :action => 'show', :id => rp}, :title => "Show Resource Pool '#{rp.name}'")
    end
    h
  end

  def graphical_storage
    storage = @record.storage
    label = ui_lookup(:table => "storages")
    # TODO: Why is this name not truncated like the others?
    h = {:label => label, :image => "storage", :value => (storage.nil? ? "None" : storage.name)}
    if storage && role_allows(:feature => "storage_show")
      h[:link] = link_to("", {:controller => "storage", :action => 'show', :id => storage}, :title => "Show #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_availability_zone
    availability_zone = @record.availability_zone
    label = ui_lookup(:table=>"availability_zone")
    return nil if availability_zone.nil?
    h = {:label => label, :image => "availability_zone", :value => availability_zone.name.truncate(13)}
    if role_allows(:feature => "availability_zone_show")
      h[:link] = link_to("", {:controller => 'availability_zone', :action => 'show', :id => availability_zone}, :title => "Show #{label} '#{availability_zone.name}'")
    end
    h
  end

  def graphical_flavor
    flavor = @record.flavor
    label = ui_lookup(:model => "flavor")
    h = {:label => label, :image => "flavor", :value => (flavor.nil? ? "None" : flavor.name.truncate(13))}
    if flavor && role_allows(:feature => "flavor_show")
      h[:link] = link_to("", {:controller => 'flavor', :action => 'show', :id => flavor}, :title => "Show #{label} '#{flavor.name}'")
    end
    h
  end

  def graphical_service
    h = {:label => "Service", :image => "service"}
    service = @record.service
    if service.nil?
      h[:value] = "None"
    else
      h[:value] = service.name.truncate(13)
      h[:link]  = link_to("", {:controller => "service", :action => 'show', :id => service}, :title => "Show this Service", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_parent_vm
    h = {:label => "Parent VM", :image => "vm"}
    parent_vm = @record.with_relationship_type("genealogy") { |r| r.parent }
    if parent_vm.nil?
      h[:value] = "None"
    else
      h[:value] = parent_vm.name.truncate(13)
      url, action = set_controller_action
      h[:link]  = link_to("", {:controller => url, :action => action, :id => parent_vm}, :remote => @explorer, :title => "Show parent VM '#{parent_vm.name}'")
    end
    h
  end

  def graphical_genealogy
    {:label => "VM Genealogy",
     :image => "genealogy",
     :link  => link_to("",
                       {:controller => controller.controller_name,
                        :action     => 'show',
                        :display    => 'vmtree_info',
                        :id         => @record
                       },
                       "data-miq_sparkle_on" => true,
                       :remote               => @explorer,
                       :title                => "Show virtual machine genealogy"
                      )
    }
  end

  def graphical_drift
    return nil unless role_allows(:feature => "vm_drift")
    h = {:label => "Drift History", :image => "drift"}
    num = @record.number_of(:drift_states)
    if num == 0
      h[:value] = "None"
    else
      h[:value] = num
      h[:link]  = link_to("", {:action => 'drift_history', :id => @record}, :remote => @explorer, :title => "Show virtual machine drift history")
    end
    h
  end

  def graphical_scan_history
    # TODO: Why is this image different than textual?
    h = {:label => "Analysis History", :image => "extract"}
    num = @record.number_of(:scan_histories)
    if num == 0
      h[:value] = "None"
    else
      h[:value] = num
      h[:link]  = link_to("", {:action => 'scan_histories', :id => @record}, :remote => @explorer, :title => "Show virtual machine analysis history")
    end
    h
  end

  def graphical_vdi_desktop
    return nil unless get_vmdb_config[:product][:vdi]
    vdi_desktop = @record.vdi_desktop
    label = ui_lookup(:table=>"vdi_desktop")
    h = {:label => label, :image => "vdi_desktop", :value => (vdi_desktop.nil? ? "None" : vdi_desktop.name.truncate(13))}
    if vdi_desktop && role_allows(:feature => "vdi_desktop_show")
      h[:link] = link_to("", {:controller => "vdi_desktop", :action => 'show', :id => vdi_desktop}, :title => "Show #{label} '#{vdi_desktop.name}'", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_users
    num = @record.number_of(:users)
    h = {:label => "Users", :image => "user", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'users', :id => @record, :db => controller.controller_name}, :remote => @explorer, :title => "Show the #{pluralize(num, 'user')} defined on this VM")
    end
    h
  end

  def graphical_groups
    num = @record.number_of(:groups)
    h = {:label => "Groups", :image => "group", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'groups', :id => @record, :db => controller.controller_name}, :remote => @explorer, :title => "Show the #{pluralize(num, 'group')} defined on this VM")
    end
    h
  end

  def graphical_patches
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:patches)
    h = {:label => "Patches", :image => "patch", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'patches', :id => @record, :db => controller.controller_name}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Patch')} defined on this VM")
    end
    h
  end

  def graphical_guest_applications
    os = @record.os_image_name.downcase
    return nil if os == "unknown"
    label = (os =~ /linux/) ? "Package" : "Application"
    num = @record.number_of(:guest_applications)
    h = {:label => label.pluralize, :image => "guest_application", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'guest_applications', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, label)} installed on this VM")
    end
    h
  end

  def graphical_init_processes
    os = @record.os_image_name.downcase
    return nil unless os =~ /linux/
    num = @record.number_of(:linux_initprocesses)
    h = {:label => "Init Processes", :image => "linuxinitprocesses", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'linux_initprocesses', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Init Process')} installed on this VM")
    end
    h
  end

  def graphical_win32_services
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:win32_services)
    h = {:label => "Win32 Services", :image => "win32service", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'win32_services', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Win32 Service')} installed on this VM")
    end
    h
  end

  def graphical_kernel_drivers
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:kernel_drivers)
    h = {:label => "Kernel Drivers", :image => "kernel_driver", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'kernel_drivers', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Kernel Driver')} installed on this VM")
    end
    h
  end

  def graphical_filesystem_drivers
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:filesystem_drivers)
    h = {:label => "File System Drivers", :image => "filesystem_driver", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'filesystem_drivers', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'File System Driver')} installed on this VM")
    end
    h
  end

  def graphical_filesystems
    num = @record.number_of(:filesystems)
    h = {:label => "Files", :image => "filesystems", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'filesystems', :id => @record}, :title => "Show the #{pluralize(num, 'File')} installed on this VM")
    end
    h
  end

  def graphical_registry_items
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:registry_items)
    # TODO: Why is this label different from the link hover text?
    h = {:label => "Registry Entries", :image => "registry_item", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'registry_items', :id => @record}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Registry Item')} installed on this VM")
    end
    h
  end

  def graphical_disks
    num = @record.hardware.nil? ? 0 : @record.hardware.number_of(:disks)
    h = {:label => "Disks", :image => "disks", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'disks'}, :remote => @explorer, :title => "Show Disks", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_advanced_settings
    num = @record.number_of(:advanced_settings)
    h = {:label => "Advanced Settings", :image => "advancedsetting", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'advanced_settings', :id => @record, :db => controller.controller_name}, :remote => @explorer, :title => "Show the #{pluralize(num, 'Advanced Setting')} on this VM")
    end
    h
  end

  def graphical_processes
    h = {:label => "Running Processes", :image => "processes"}
    date = last_date(:processes)
    if date.nil?
      h[:value] = "Not Available"
    else
      # TODO: Why does this date differ in style from the compliance one?
      h[:value] = "From #{time_ago_in_words(date.in_time_zone(Time.zone)).titleize} Ago"
      h[:link]  = link_to("", {:action => 'processes', :id => @record}, :remote => @explorer, :title => "Show the last Collected Running Processes for this VM")
    end
    h
  end

  def graphical_event_logs
    num = @record.operating_system.nil? ? 0 : @record.operating_system.number_of(:event_logs)
    h = {:label => "Event Logs", :image => "event_logs", :value => (num == 0 ? "Not Available" : "Available")}
    if num > 0
      h[:link] = link_to("", {:action => 'event_logs', :id => @record}, :remote => @explorer, :title => "Show event logs on this VM")
    end
    h
  end

  def graphical_storage_systems
    num = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :image => "ontap_storage_system", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_storage_systems"}, :remote => @explorer, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_storage_volumes
    num = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_volume_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_storage_volumes"}, :remote => @explorer, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_file_shares
    num = @record.file_shares_size
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature => "ontap_file_share_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_file_shares"}, :remote => @explorer, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_logical_disks
    num = @record.logical_disks_size
    label = ui_lookup(:tables => "ontap_logical_disk")
    h = {:label => label, :image => "ontap_logical_disk", :value => num}
    if num > 0 && role_allows(:feature => "ontap_logical_disk_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_logical_disks"}, :remote => @explorer, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end
end
