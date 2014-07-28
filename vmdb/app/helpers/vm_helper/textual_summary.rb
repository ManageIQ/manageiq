module VmHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    items = %w{name region server description hostname ipaddress custom_1 container host_platform tools_status osinfo cpu_affinity snapshots advanced_settings resources guid}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_lifecycle
    items = %w{discovered analyzed retirement_date provisioned owner group}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{ems cluster host resource_pool storage service parent_vm genealogy drift scan_history vdi_desktop cloud_network cloud_subnet}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_vm_cloud_relationships
    items = %w{ems availability_zone flavor drift scan_history}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_template_cloud_relationships
    items = %w{ems drift scan_history}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_security
    items = %w{users groups patches}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_configuration
    items = %w{guest_applications init_processes win32_services kernel_drivers filesystem_drivers filesystems registry_items}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_datastore_allocation
    items = %w{disks disks_aligned thin_provisioned allocated_disks allocated_memory allocated_total}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_datastore_usage
    items = %w{usage_disks usage_memory usage_snapshots usage_disk_storage usage_overcommitted}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_diagnostics
    items = %w{processes event_logs}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_storage_relationships
    items = %w{storage_systems storage_volumes logical_disks file_shares}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_vmsafe
    items = %w{vmsafe_enable vmsafe_agent_address vmsafe_agent_port vmsafe_fail_open vmsafe_immutable_vm vmsafe_timeout}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_miq_custom_attributes
    items = %w{miq_custom_attributes}
    ret = items.collect { |m| self.send("textual_#{m}") }.flatten.compact
    return ret.blank? ? nil : ret
  end

  def textual_group_ems_custom_attributes
    items = %w{ems_custom_attributes}
    ret = items.collect { |m| self.send("textual_#{m}") }.flatten.compact
    return ret.blank? ? nil : ret
  end

  def textual_group_compliance
    items = %w{compliance_status compliance_history}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_power_management
    items = %w{power_state boot_time state_changed_on}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_normal_operating_ranges
    items = %w{normal_operating_ranges_cpu normal_operating_ranges_cpu_usage normal_operating_ranges_memory normal_operating_ranges_memory_usage}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_tags
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_vdi_endpoint_device
    return nil unless get_vmdb_config[:product][:vdi]
    items = %w{vdi_endpoint_name vdi_endpoint_type vdi_endpoint_ip_address vdi_endpoint_mac_address}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_vdi_connection
    return nil unless get_vmdb_config[:product][:vdi]
    items = %w{vdi_connection_name vdi_connection_logon_server vdi_connection_session_name vdi_connection_remote_ip_address vdi_connection_dns_name vdi_connection_url vdi_connection_session_type}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_vdi_user
    return nil unless get_vmdb_config[:product][:vdi]
    items = %w{vdi_user_name vdi_user_ldap vdi_user_domain vdi_user_dns_domain vdi_user_logon_time vdi_user_appdata vdi_user_home_drive vdi_user_home_share vdi_user_home_path}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_region
    return nil if @record.region_number == MiqRegion.my_region_number
    h = {:label => "Region"}
    reg = @record.miq_region
    url = reg.remote_ui_url
    h[:value] = if url
      # TODO: Why is this link different than the others?
      link_to(reg.description, url_for(:host => url, :action => 'show', :id => @record), :title => "Connect to this VM in its Region", :onclick => "return miqClickAndPop(this);")
    else
      reg.description
    end
    h
  end

  def textual_name
    h = {:label => "Name", :value => @record.name}
    if @record.vdi?
      if params[:controller] != "vm_vdi"
        if role_allows(:feature => "vm_vdi_view")
          h[:title] = "Show this VDI VM in the VDI tab"
          h[:link]  = url_for(:controller => 'vm_vdi', :action => 'show', :id => @record.id)
        end
      else
        if role_allows(:feature => "vandt_accord") || role_allows(:feature => "vm_filter_accord")
          h[:title] = "Show this VDI VM in the Virtual Machines tab"
          h[:link]  = url_for(:controller => 'vm_or_template', :action => 'show', :id => @record.id)
        end
      end
    end
    h
  end

  def textual_server
    return nil if @record.miq_server.nil?
    {:label => "Server", :value => "#{@record.miq_server.name} [#{@record.miq_server.id}]"}
  end

  def textual_description
    return nil if @record.description.blank?
    {:label => "Description", :value => @record.description}
  end

  def textual_hostname
    hostnames = @record.hostnames
    {:label => (hostnames.size > 1 ? "Hostname".pluralize : "Hostname"), :value => hostnames.join(", ")}
  end

  def textual_ipaddress
    ips = @record.ipaddresses
    {:label => (ips.size > 1 ? "IP Address".pluralize : "IP Address"), :value => ips.join(", ")}
  end

  def textual_custom_1
    return nil if @record.custom_1.blank?
    {:label => "Custom Identifier", :value => @record.custom_1}
  end

  def textual_container
    h = {:label => "Container"}
    vendor = @record.vendor
    if vendor.blank?
      h[:value] = "None"
    else
      h[:image] = "vendor-#{vendor.downcase}"
      h[:value] = "#{vendor} (#{pluralize(@record.num_cpu, 'CPU')}, #{@record.mem_cpu} MB)"
      h[:title] = "Show VMM container information"
      h[:explorer] = true
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hv_info')
    end
    h
  end

  def textual_host_platform
    {:label => "Parent Host Platform", :value => (@record.host.nil? ? "N/A" : @record.v_host_vmm_product)}
  end

  def textual_tools_status
    {:label => "Platform Tools", :value => (@record.tools_status.nil? ? "N/A" : @record.tools_status)}
  end

  def textual_osinfo
    h = {:label => "Operating System"}
    os = @record.operating_system.nil? ? nil : @record.operating_system.product_name
    if os.blank?
      h[:value] = "Unknown"
    else
      h[:image] = "os-#{@record.os_image_name.downcase}"
      h[:value] = os
      h[:title] = "Show OS container information"
      h[:explorer] = true
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'os_info')
    end
    h
  end

  def textual_cpu_affinity
    {:label => "CPU Affinity", :value => @record.cpu_affinity}
  end

  def textual_snapshots
    num = @record.number_of(:snapshots)
    h = {:label => "Snapshots", :image => "snapshot", :value => (num == 0 ? "None" : num)}
    if role_allows(:feature => "vm_snapshot_show_list")
      h[:title] = "Show the snapshot info for this VM"
      h[:explorer] = true
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'snapshot_info')
    end
    h
  end

  def textual_advanced_settings
    num = @record.number_of(:advanced_settings)
    h = {:label => "Advanced Settings", :image => "advancedsetting", :value => num}
    if num > 0
      h[:title] = "Show the advanced settings on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:action => 'advanced_settings', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_resources
    {:label => "Resources", :value => "Available", :title => "Show resources of this VM", :explorer => true,
      :link => url_for(:action => 'show', :id => @record, :display => 'resources_info')}
  end

  def textual_guid
    {:label => "Management Engine GUID", :value => @record.guid}
  end

  def textual_discovered
    {:label => "Discovered", :image => "discover", :value => format_timezone(@record.created_on)}
  end

  def textual_analyzed
    {:label => "Last Analyzed", :image => "scan", :value => (@record.last_sync_on.nil? ? "Never" : format_timezone(@record.last_sync_on))}
  end

  def textual_retirement_date
    {:label => "Retirement Date", :image => "retirement", :value => (@record.retires_on.nil? ? "Never" : @record.retires_on.to_time.strftime("%x"))}
  end

  def textual_provisioned
    req = @record.miq_provision.nil? ? nil : @record.miq_provision.miq_request
    return nil if req.nil?
    {:label => "Provisioned On", :value => req.fulfilled_on.nil? ? "" : format_timezone(req.fulfilled_on)}
  end

  def textual_owner
    return nil if @record.evm_owner.nil?
    {:label => "Owner", :value => @record.evm_owner.name}
  end

  def textual_group
    return nil if @record.miq_group.nil?
    {:label => "Group", :value => @record.miq_group.description}
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_infra")
    h = {:label => label, :image => "vendor-#{ems.emstype.downcase}", :value => ems.name}
    if role_allows(:feature => "ems_infra_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_infra', :action => 'show', :id => ems)
    end
    h
  end

  def textual_cluster
    cluster = @record.ems_cluster
    h = {:label => "Cluster", :image => "ems_cluster", :value => (cluster.nil? ? "None" : cluster.name)}
    if cluster && role_allows(:feature => "ems_cluster_show")
      h[:title] = "Show this VM's Cluster"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => cluster)
    end
    h
  end

  def textual_host
    host = @record.host
    h = {:label => "Host", :image => "host", :value => (host.nil? ? "None" : host.name)}
    if host && role_allows(:feature => "host_show")
      h[:title] = "Show this VM's Host"
      h[:link]  = url_for(:controller => 'host', :action => 'show', :id => host)
    end
    h
  end

  def textual_resource_pool
    rp = @record.parent_resource_pool
    image = (rp && rp.vapp?) ? "vapp" : "resource_pool"
    h = {:label => "Resource Pool", :image => image, :value => (rp.nil? ? "None" : rp.name)}
    if rp && role_allows(:feature => "resource_pool_show")
      h[:title] = "Show this VM's Resource Pool"
      h[:link]  = url_for(:controller => 'resource_pool', :action => 'show', :id => rp)
    end
    h
  end

  def textual_storage
    storages = @record.storages
    label = ui_lookup(:tables=>"storages")
    h = {:label => label, :image => "storage"}
    if storages.empty?
      h[:value] = "None"
    elsif storages.length == 1
      storage = storages.first
      h[:value] = storage.name
      h[:title] = "Show this VM's #{label}"
      h[:link]  = url_for(:controller => 'storage', :action => 'show', :id => storage)
    else
      h.delete(:image) # Image will be part of each line item, instead
      main = @record.storage
      h[:value] = storages.sort_by { |s| s.name.downcase }.collect do |s|
        {:image => "storage", :value => "#{s.name}#{" (main)" if s == main}", :title => "Show this VM's #{label}", :link => url_for(:controller => 'storage', :action => 'show', :id => s)}
      end
    end
    h
  end

  def textual_availability_zone
    availability_zone = @record.availability_zone
    label = ui_lookup(:table => "availability_zone")
    h = {:label => label, :image => "availability_zone", :value => (availability_zone.nil? ? "None" : availability_zone.name)}
    if availability_zone && role_allows(:feature => "availability_zone_show")
      h[:title] = "Show this VM's #{label}"
      h[:link]  = url_for(:controller => 'availability_zone', :action => 'show', :id => availability_zone)
    end
    h
  end

  def textual_flavor
    flavor = @record.flavor
    label = ui_lookup(:table => "flavor")
    h = {:label => label, :image => "flavor", :value => (flavor.nil? ? "None" : flavor.name)}
    if flavor && role_allows(:feature => "flavor_show")
      h[:title] = "Show this VM's #{label}"
      h[:link]  = url_for(:controller => 'flavor', :action => 'show', :id => flavor)
    end
    h
  end

  def textual_service
    h = {:label => "Service", :image => "service"}
    service = @record.service
    if service.nil?
      h[:value] = "None"
    else
      h[:value] = service.name
      h[:title] = "Show this Service"
      h[:link]  = url_for(:controller => 'service', :action => 'show', :id => service)
    end
    h
  end

  def textual_parent_vm
    h = {:label => "Parent VM", :image => "vm"}
    parent_vm = @record.with_relationship_type("genealogy") { |r| r.parent }
    if parent_vm.nil?
      h[:value] = "None"
    else
      h[:value] = parent_vm.name
      h[:title] = "Show this VM's parent"
      h[:explorer] = true
      url, action = set_controller_action
      h[:link]  = url_for(:controller => url, :action => action , :id => parent_vm)
    end
    h
  end

  def textual_genealogy
    {
      :label    => "Genealogy",
      :image    => "genealogy",
      :value    => "Show parent and child VMs",
      :title    => "Show virtual machine genealogy",
      :explorer => true,
      :spinner  => true,
      :link     => url_for(
                    :controller => controller.controller_name,
                    :action     => 'show',
                    :id         => @record,
                    :display    => "vmtree_info"
                    )
    }
  end

  def textual_drift
    return nil unless role_allows(:feature => "vm_drift")
    h = {:label => "Drift History", :image => "drift"}
    num = @record.number_of(:drift_states)
    if num == 0
      h[:value] = "None"
    else
      h[:value] = num
      h[:title] = "Show virtual machine drift history"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'drift_history', :id => @record)
    end
    h
  end

  def textual_scan_history
    h = {:label => "Analysis History", :image => "scan"}
    num = @record.number_of(:scan_histories)
    if num == 0
      h[:value] = "None"
    else
      h[:value] = num
      h[:title] = "Show virtual machine analysis history"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'scan_histories', :id => @record)
    end
    h
  end

  def textual_vdi_desktop
    return nil unless get_vmdb_config[:product][:vdi]
    vdi_desktop = @record.vdi_desktop
    label = ui_lookup(:table=>"vdi_desktop")
    h = {:label => label, :image => "vdi_desktop", :value => (vdi_desktop.nil? ? "None" : vdi_desktop.name)}
    if vdi_desktop && role_allows(:feature => "vdi_desktop_show")
      h[:title] = "Show #{label} '#{vdi_desktop.name}'"
      h[:link]  = url_for(:controller => "vdi_desktop", :action => 'show', :id => vdi_desktop)
    end
    h
  end

  def textual_users
    num = @record.number_of(:users)
    h = {:label => "Users", :image => "user", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'user')} defined on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:action => 'users', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_groups
    num = @record.number_of(:groups)
    h = {:label => "Groups", :image => "group", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'group')} defined on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:action => 'groups', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_patches
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:patches)
    h = {:label => "Patches", :image => "patch", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Patch')} defined on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:action => 'patches', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_guest_applications
    os = @record.os_image_name.downcase
    return nil if os == "unknown"
    label = (os =~ /linux/) ? "Package" : "Application"
    num = @record.number_of(:guest_applications)
    h = {:label => label.pluralize, :image => "guest_application", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, label)} installed on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'guest_applications', :id => @record)
    end
    h
  end

  def textual_init_processes
    os = @record.os_image_name.downcase
    return nil unless os =~ /linux/
    num = @record.number_of(:linux_initprocesses)
    # TODO: Why is this image different than graphical?
    h = {:label => "Init Processes", :image => "gears", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Init Process')} installed on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'linux_initprocesses', :id => @record)
    end
    h
  end

  def textual_win32_services
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:win32_services)
    h = {:label => "Win32 Services", :image => "win32service", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Win32 Service')} installed on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'win32_services', :id => @record)
    end
    h
  end

  def textual_kernel_drivers
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:kernel_drivers)
    # TODO: Why is this image different than graphical?
    h = {:label => "Kernel Drivers", :image => "gears", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Kernel Driver')} installed on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'kernel_drivers', :id => @record)
    end
    h
  end

  def textual_filesystem_drivers
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:filesystem_drivers)
    # TODO: Why is this image different than graphical?
    h = {:label => "File System Drivers", :image => "gears", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'File System Driver')} installed on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'filesystem_drivers', :id => @record)
    end
    h
  end

  def textual_filesystems
    num = @record.number_of(:filesystems)
    h = {:label => "Files", :image => "filesystems", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'File')} installed on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'filesystems', :id => @record)
    end
    h
  end

  def textual_registry_items
    os = @record.os_image_name.downcase
    return nil if os == "unknown" || os =~ /linux/
    num = @record.number_of(:registry_items)
    # TODO: Why is this label different from the link title text?
    h = {:label => "Registry Entries", :image => "registry_item", :value => num}
    if num > 0
      h[:title] = "Show the #{pluralize(num, 'Registry Item')} installed on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'registry_items', :id => @record)
    end
    h
  end

  def textual_disks
    num = @record.hardware.nil? ? 0 : @record.hardware.number_of(:disks)
    h = {:label => "Number of Disks", :image => "devices", :value => num}
    if num > 0
      h[:title] = "Show disks on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "disks")
    end
    h
  end

  def textual_disks_aligned
    {:label => "Disks Aligned", :value => @record.disks_aligned}
  end

  def textual_thin_provisioned
    {:label => "Thin Provisioning Used", :value => @record.thin_provisioned.to_s.capitalize}
  end

  def textual_allocated_disks
    h = {:label => "Disks"}
    value = @record.allocated_disk_storage
    h[:title] = value.nil? ? "N/A" : "#{number_with_delimiter(value)} bytes"
    h[:value] = value.nil? ? "N/A" : number_to_human_size(value, :precision => 2)
    h
  end

  def textual_allocated_memory
    h = {:label => "Memory"}
    value = @record.ram_size_in_bytes_by_state
    h[:title] = value.nil? ? "N/A" : "#{number_with_delimiter(value)} bytes"
    h[:value] = value.nil? ? "N/A" : number_to_human_size(value, :precision => 2)
    h
  end

  def textual_allocated_total
    h = textual_allocated_disks
    h[:label] = "Total Allocation"
    h
  end

  def textual_usage_disks
    textual_allocated_disks
  end

  def textual_usage_memory
    textual_allocated_memory
  end

  def textual_usage_snapshots
    h = {:label => "Snapshots"}
    value = @record.snapshot_storage
    h[:title] = value.nil? ? "N/A" : "#{number_with_delimiter(value)} bytes"
    h[:value] = value.nil? ? "N/A" : number_to_human_size(value, :precision => 2)
    h
  end

  def textual_usage_disk_storage
    h = {:label => "Total Datastore Used Space"}
    value = @record.used_disk_storage
    h[:title] = value.nil? ? "N/A" : "#{number_with_delimiter(value)} bytes"
    h[:value] = value.nil? ? "N/A" : number_to_human_size(value, :precision => 2)
    h
  end

  def textual_usage_overcommitted
    h = {:label => "Unused/Overcommited Allocation"}
    value = @record.uncommitted_storage
    h[:title] = value.nil? ? "N/A" : "#{number_with_delimiter(value)} bytes"
    h[:value] = if value.nil?
      "N/A"
    else
      v = number_to_human_size(value.abs, :precision => 2)
      v = "(#{v}) * Overallocated" if value < 0
      v
    end
    h
  end

  def textual_processes
    h = {:label => "Running Processes", :image => "processes"}
    date = last_date(:processes)
    if date.nil?
      h[:value] = "Not Available"
    else
      # TODO: Why does this date differ in style from the compliance one?
      h[:value] = "From #{time_ago_in_words(date.in_time_zone(Time.zone)).titleize} Ago"
      h[:title] = "Show Running Processes on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'processes', :id => @record)
    end
    h
  end

  def textual_event_logs
    num = @record.operating_system.nil? ? 0 : @record.operating_system.number_of(:event_logs)
    h = {:label => "Event Logs", :image => "event_logs", :value => (num == 0 ? "Not Available" : "Available")}
    if num > 0
      h[:title] = "Show Event Logs on this VM"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'event_logs', :id => @record)
    end
    h
  end

  def textual_storage_systems
    num = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :image => "ontap_storage_system", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:title] = "Show all #{label}"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_systems")
    end
    h
  end

  def textual_storage_volumes
    num = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_volume_show_list")
      h[:title] = "Show all #{label}"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_storage_volumes")
    end
    h
  end

  def textual_file_shares
    num = @record.file_shares_size
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature => "ontap_file_share_show_list")
      h[:title] = "Show all #{label}"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_file_shares")
    end
    h
  end

  def textual_logical_disks
    num = @record.logical_disks_size
    label = ui_lookup(:tables => "ontap_logical_disk")
    h = {:label => label, :image => "ontap_logical_disk", :value => num}
    if num > 0 && role_allows(:feature => "ontap_logical_disk_show_list")
      h[:title] = "Show all #{label}"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "ontap_logical_disks")
    end
    h
  end

  def textual_vmsafe_enable
    return nil if @record.vmsafe_enable
    {:label => "Enable", :value => "false"}
  end

  def textual_vmsafe_agent_address
    return nil unless @record.vmsafe_enable
    {:label => "Agent Address", :value => @record.vmsafe_agent_address}
  end

  def textual_vmsafe_agent_port
    return nil unless @record.vmsafe_enable
    {:label => "Agent Port", :value => @record.vmsafe_agent_port}
  end

  def textual_vmsafe_fail_open
    return nil unless @record.vmsafe_enable
    {:label => "Fail Open", :value => @record.vmsafe_fail_open}
  end

  def textual_vmsafe_immutable_vm
    return nil unless @record.vmsafe_enable
    {:label => "Immutable VM", :value => @record.vmsafe_immutable_vm}
  end

  def textual_vmsafe_timeout
    return nil unless @record.vmsafe_enable
    {:label => "Timeout (ms)", :value => @record.vmsafe_timeout_ms}
  end

  def textual_miq_custom_attributes
    attrs = @record.miq_custom_attributes
    return nil if attrs.blank?
    attrs.collect { |a| {:label => a.name, :value => a.value} }
  end

  def textual_ems_custom_attributes
    attrs = @record.ems_custom_attributes
    return nil if attrs.blank?
    attrs.collect { |a| {:label => a.name, :value => a.value} }
  end

  def textual_compliance_status
    h = {:label => "Status"}
    if @record.number_of(:compliances) == 0
      h[:value] = "Never Verified"
    else
      compliant = @record.last_compliance_status
      date      = @record.last_compliance_timestamp
      h[:image] = compliant ? "check" : "x"
      h[:value] = "#{"Non-" unless compliant}Compliant as of #{time_ago_in_words(date.in_time_zone(Time.zone)).titleize} Ago"
      h[:title] = "Show Details of Compliance Check on #{format_timezone(date)}"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => 'compliance_history', :count => 1)
    end
    h
  end

  def textual_compliance_history
    h = {:label => "History"}
    if @record.number_of(:compliances) == 0
      h[:value] = "Not Available"
    else
      h[:image] = "compliance"
      h[:value] = "Available"
      h[:title] = "Show Compliance History of this VM (Last 10 Checks)"
      h[:explorer] = true
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => 'compliance_history')
    end
    h
  end

  def textual_power_state
    state = @record.current_state.downcase
    state = "unknown" if state.blank?
    h = {:label => "Power State", :value => state}
    h[:image] = "currentstate-#{@record.template? ? (@record.host ? "template" : "template-no-host") : state}"
    h
  end

  def textual_boot_time
    date = @record.boot_time
    {:label => "Last Boot Time", :value => (date.nil? ? "N/A" : format_timezone(date))}
  end

  def textual_state_changed_on
    date = @record.state_changed_on
    {:label => "State Changed On", :value => (date.nil? ? "N/A" : format_timezone(date))}
  end

  def textual_normal_operating_ranges_cpu
    h = {:label => "CPU", :value => []}
    [:high, "High", :avg, "Average", :low, "Low"].each_slice(2) do |key, label|
      value = @record.send("cpu_usagemhz_rate_average_#{key}_over_time_period")
      h[:value] << {:label => label, :value => (value.nil? ? "Not Available" : mhz_to_human_size(value))}
    end
    h
  end

  def textual_normal_operating_ranges_cpu_usage
    h = {:label => "CPU Usage", :value => []}
    [:high, "High", :avg, "Average", :low, "Low"].each_slice(2) do |key, label|
      value = @record.send("max_cpu_usage_rate_average_#{key}_over_time_period")
      h[:value] << {:label => label, :value => (value.nil? ? "Not Available" : number_to_percentage(value, :precision => 2))}
    end
    h
  end

  def textual_normal_operating_ranges_memory
    h = {:label => "Memory", :value => []}
    [:high, "High", :avg, "Average", :low, "Low"].each_slice(2) do |key, label|
      value = @record.send("derived_memory_used_#{key}_over_time_period")
      h[:value] << {:label => label, :value => (value.nil? ? "Not Available" : number_to_human_size(value.megabytes, :precision => 2))}
    end
    h
  end

  def textual_normal_operating_ranges_memory_usage
    h = {:label => "Memory Usage", :value => []}
    [:high, "High", :avg, "Average", :low, "Low"].each_slice(2) do |key, label|
      value = @record.send("max_mem_usage_absolute_average_#{key}_over_time_period")
      h[:value] << {:label => label, :value => (value.nil? ? "Not Available" : number_to_percentage(value, :precision => 2))}
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end

  def textual_vdi_endpoint_name
    {:label => "Name", :value => @record.vdi_endpoint_name}
  end

  def textual_vdi_endpoint_type
    {:label => "Type", :value => @record.vdi_endpoint_type}
  end

  def textual_vdi_endpoint_ip_address
    {:label => "IP Address", :value => @record.vdi_endpoint_ip_address}
  end

  def textual_vdi_endpoint_mac_address
    {:label => "MAC Address", :value => @record.vdi_endpoint_mac_address}
  end

  def vdi_connection_name
    {:label => "Name", :value => @record.vdi_connection_name}
  end

  def vdi_connection_logon_server
    {:label => "Logon Server", :value => @record.vdi_connection_logon_server}
  end

  def vdi_connection_session_name
    {:label => "Session Name", :value => @record.vdi_connection_session_name}
  end

  def vdi_connection_remote_ip_address
    {:label => "Remote IP Address", :value => @record.vdi_connection_remote_ip_address}
  end

  def vdi_connection_dns_name
    {:label => "DNS Name", :value => @record.vdi_connection_dns_name}
  end

  def vdi_connection_url
    {:label => "URL", :value => @record.vdi_connection_url}
  end

  def vdi_connection_session_type
    {:label => "Session Type", :value => @record.vdi_connection_session_type}
  end

  def vdi_user_name
    {:label => "Username", :value => @record.vdi_user_name}
  end

  def vdi_user_ldap
    return nil unless MiqLdap.using_ldap?
    ldap = @record.vdi_user_ldap
    return nil if ldap.nil?
    ldap.collect { |l| {:label => l[0], :value => l[1]} }
  end

  def vdi_user_domain
    {:label => "Domain", :value => @record.vdi_user_domain}
  end

  def vdi_user_dns_domain
    {:label => "DNS Domain", :value => @record.vdi_user_dns_domain}
  end

  def vdi_user_logon_time
    {:label => "Logon Time", :value => @record.vdi_user_logon_time}
  end

  def vdi_user_appdata
    {:label => "APPDATA", :value => @record.vdi_user_appdata}
  end

  def vdi_user_home_drive
    {:label => "HOMEDRIVE", :value => @record.vdi_user_home_drive}
  end

  def vdi_user_home_share
    {:label => "HOMESHARE", :value => @record.vdi_user_home_share}
  end

  def vdi_user_home_path
    {:label => "HOMEPATH", :value => @record.vdi_user_home_path}
  end
end
