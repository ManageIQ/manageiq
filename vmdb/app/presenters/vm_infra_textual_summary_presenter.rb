class VmCloudTextualSummaryPresenter < TextualSummaryPresenter
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #
  def textual_group_properties
    items = %w{name region server description hostname ipaddress custom_1 container host_platform tools_status osinfo cpu_affinity snapshots advanced_settings resources guid}
    call_items(items)
  end

  def textual_group_relationships
    items = %w{ems cluster host resource_pool storage service parent_vm genealogy drift scan_history vdi_desktop}
    call_items(items)
  end

  def textual_group_security
    items = %w{users groups patches}
    call_items(items)
  end

  def textual_group_datastore_allocation
    items = %w{disks disks_aligned thin_provisioned allocated_disks allocated_memory allocated_total}
    call_items(items)
  end

  def textual_group_datastore_usage
    items = %w{usage_disks usage_memory usage_snapshots usage_disk_storage usage_overcommitted}
    call_items(items)
  end

  def textual_group_storage_relationships
    items = %w{storage_systems storage_volumes logical_disks file_shares}
    call_items(items)
  end

  def textual_group_normal_operating_ranges
    items = %w{normal_operating_ranges_cpu normal_operating_ranges_cpu_usage normal_operating_ranges_memory normal_operating_ranges_memory_usage}
    call_items(items)
  end

  def textual_group_vdi_endpoint_device
    return nil unless get_vmdb_config[:product][:vdi]
    items = %w{vdi_endpoint_name vdi_endpoint_type vdi_endpoint_ip_address vdi_endpoint_mac_address}
    call_items(items)
  end

  def textual_group_vdi_connection
    return nil unless get_vmdb_config[:product][:vdi]
    items = %w{vdi_connection_name vdi_connection_logon_server vdi_connection_session_name vdi_connection_remote_ip_address vdi_connection_dns_name vdi_connection_url vdi_connection_session_type}
    call_items(items)
  end

  def textual_group_vdi_user
    return nil unless get_vmdb_config[:product][:vdi]
    items = %w{vdi_user_name vdi_user_ldap vdi_user_domain vdi_user_dns_domain vdi_user_logon_time vdi_user_appdata vdi_user_home_drive vdi_user_home_share vdi_user_home_path}
    call_items(items)
  end


  #
  # Items
  #
  def textual_hostname
    hostnames = @record.hostnames
    {:label => (hostnames.size > 1 ? "Hostname".pluralize : "Hostname"), :value => hostnames.join(", ")}
  end

  def textual_host_platform
    {:label => "Parent Host Platform", :value => (@record.host.nil? ? "N/A" : @record.v_host_vmm_product)}
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
      h[:title] = "Show this #{label}"
      h[:link]  = url_for(:controller => 'storage', :action => 'show', :id => storage)
    else
      h.delete(:image) # Image will be part of each line item, instead
      main = @record.storage
      h[:value] = storages.sort_by { |s| s.name.downcase }.collect do |s|
        {:image => "storage", :value => "#{s.name}#{" (main)" if s == main}", :title => "Show this #{label}", :link => url_for(:controller => 'storage', :action => 'show', :id => s)}
      end
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
    {:label => "Genealogy", :image => "genealogy", :value => "Show parent and child VMs", :title => "Show virtual machine genealogy",
      :explorer => true, :link => url_for(:controller => controller.controller_name, :action => 'show', :id => @record, :display => "vmtree_info")}
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