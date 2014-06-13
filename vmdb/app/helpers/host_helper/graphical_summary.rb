module HostHelper::GraphicalSummary
  # TODO: Verify why there are onclick events with miqCheckForChanges(), but only on some links.

  #
  # Groups
  #

  def graphical_group_properties
    items = %w{vmm_vendor osinfo state devices network storage_adapters compliances}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_relationships
    items = %w{ems cluster storage resource_pool vms miq_templates drift_history}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_security
    return nil if @record.is_vmware_esxi?
    items = %w{users groups patches firewall_rules}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_configuration
    items = %w{guest_applications host_services filesystems advanced_settings}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_diagnostics
    return nil unless get_vmdb_config[:product][:proto]
    items = %w{esx_logs}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_storage_relationships
    items = %w{storage_systems storage_volumes logical_disks file_shares}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_vmm_vendor
    h = {:label => "VMM"}
    if @vmminfo == nil || @vmminfo.empty?
      h[:value] = "Unknown"
      h[:image] = "unknown"
    else
      h[:image] = "vendor-#{@record.vmm_vendor.downcase}"
      h[:value] = @vmminfo[0][:description]
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'hv_info'}, :title => "Show #{h[:label]} container information")
    end
    h
  end

  def graphical_osinfo
    h = {:label => "OS", :image => @record.os_image_name.downcase}
    if @osinfo == nil || @osinfo.empty?
      h[:value] = "Unknown"
      h[:image] = "unknown"
    else
      value = @osinfo[0][:description].dup
      if !@record.operating_system.version.blank?
        value << " #{@record.operating_system.version}"
      end
      if !@record.operating_system.build_number.blank?
        value << " Build #{@record.operating_system.build_number}"
      end
      h[:value] = value
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'os_info'}, :title => "Show Host #{h[:label]} information")
    end
    h
  end

  def graphical_state
    state = @record.state.to_s.downcase
    state = "unknown" if state.blank?
    {:label => "Power State", :image => state, :value => state}
  end

  def graphical_devices
    h = {:label => "Devices"}
    if @devices == nil || @devices.empty?
      h[:value] = "0"
      h[:image] = "devices"
    else
      h[:image] = "devices"
      h[:value] = @devices.length
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'devices'}, :title => "Show Host #{h[:label]}")
    end
    h
  end

  def graphical_network
    num = @record.number_of(:switches)
    h = {:label => "Network"}
    if num == 0
      h[:value] = "N/A"
      h[:image] = "network"
    else
      h[:image] = "network"
      h[:value] = "Available"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'network'}, :title => "Show Host #{h[:label]}")
    end
    h
  end

  def graphical_storage_adapters
    num = @record.hardware.nil? ? 0 : @record.hardware.number_of(:storage_adapters)
    h = {:label => "Storage Adapters"}
    if num == 0
      h[:value] = "0"
      h[:image] = "sa"
    else
      h[:image] = "sa"
      h[:value] = num
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'storage_adapters'}, :title => "Show Host #{h[:label]}")
    end
    h
  end

  def graphical_compliances
    h = {:image => "compliance"}
    if @record.number_of(:compliances) == 0
      h[:label] = "Compliance"
      h[:value] = "Never Validated"
    else
      h[:label] = "#{"Non-" unless @record.last_compliance_status}Compliance Status"
      h[:value] = "#{time_ago_in_words(@record.last_compliance.timestamp.in_time_zone(Time.zone)).titleize} Ago"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'compliance_history'}, :title => "Show Compliance History of this Host (Last 10 Checks)")
    end
    h
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

  def graphical_resource_pool
    label = "Resource Pools"
    num = @record.number_of(:resource_pools)
    h     = {:label => label, :image => "resource_pool", :value => num}
    if num > 0 && role_allows(:feature => "resource_pool_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'resource_pools'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_storage
    label = ui_lookup(:tables=>"storages")
    num   = @record.number_of(:storages)
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'storages'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_vms
    label = "VMs"
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'vms'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_miq_templates
    label = ui_lookup(:tables=>"miq_template")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'miq_templates'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_drift_history
    return nil unless role_allows(:feature=>"host_drift")
    label = "Drift History"
    num   = @record.number_of(:drift_states)
    h     = {:label => label, :image => "drift", :value => num > 0 ? num : "None"}
    if num > 0
      h[:link] = link_to("", {:action => 'drift_history', :id => @record}, :title => "Show Host #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_users
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:users)
    h = {:label => "Users", :image => "user", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'users', :id => @record, :db => controller.controller_name}, :title => "Show the #{pluralize(num, 'user')} defined on this Host")
    end
    h
  end

  def graphical_groups
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:groups)
    h = {:label => "Groups", :image => "group", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'groups', :id => @record, :db => controller.controller_name}, :title => "Show the #{pluralize(num, 'group')} defined on this Host")
    end
    h
  end

  def graphical_patches
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:patches)
    h = {:label => "Patches", :image => "patch", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'patches', :id => @record, :db => controller.controller_name}, :title => "Show the #{pluralize(num, 'Patch')} defined on this Host")
    end
    h
  end

  def graphical_firewall_rules
    return nil if @record.is_vmware_esxi?
    num = @record.number_of(:firewall_rules)
    h = {:label => "Firewall Rules", :image => "firewallrule", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'patches', :id => @record, :db => controller.controller_name}, :title => "Show the #{pluralize(num, 'Patch')} defined on this Host")
    end
    h
  end

  def graphical_guest_applications
    label = "Package"
    num = @record.number_of(:guest_applications)
    h = {:label => label.pluralize, :image => "guest_application", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'guest_applications', :id => @record, :db => controller.controller_name}, :title => "Show the #{pluralize(num, label)} installed on this Host")
    end
    h
  end

  def graphical_host_services
    num = @record.number_of(:host_services)
    h = {:label => "Services", :image => "service", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'host_services', :id => @record}, :db => controller.controller_name, :title => "Show the #{pluralize(num, 'Service')} installed on this Host")
    end
    h
  end

  def graphical_filesystems
    num = @record.number_of(:filesystems)
    h = {:label => "Files", :image => "filesystems", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'filesystems', :id => @record, :db => controller.controller_name}, :title => "Show the #{pluralize(num, 'File')} installed on this Host")
    end
    h
  end

  def graphical_advanced_settings
    num = @record.number_of(:advanced_settings)
    h = {:label => "Advanced Settings", :image => "advancedsetting", :value => num}
    if num > 0
      h[:link] = link_to("", {:action => 'advanced_settings', :id => @record, :db => controller.controller_name}, :title => "Show the #{pluralize(num, 'Advanced Setting')} on this Host")
    end
    h
  end

  def graphical_esx_logs
    h = {:label => "ESX Logs"}
    if @record.operating_system.nil? || @record.operating_system.number_of(:event_logs) == 0
      h[:value] = "Not Available"
      h[:image] = "logs"
    else
      h[:image] = "logs"
      h[:value] = "Available"
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'event_logs'}, :title => "Show Host #{h[:label]}")
    end
    h
  end

  def graphical_storage_systems
    num = @record.storage_systems_size
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :image => "ontap_storage_system", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_storage_systems"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_storage_volumes
    num = @record.storage_volumes_size
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_volume_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_storage_volumes"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_file_shares
    num = @record.file_shares_size
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature => "ontap_file_share_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_file_shares"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_logical_disks
    num = @record.logical_disks_size
    label = ui_lookup(:tables => "ontap_logical_disk")
    h = {:label => label, :image => "ontap_logical_disk", :value => num}
    if num > 0 && role_allows(:feature => "ontap_logical_disk_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_logical_disks"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end
end
