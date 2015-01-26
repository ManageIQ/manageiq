module EmsClusterHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_host_totals
    items = %w{aggregate_cpu_speed aggregate_memory aggregate_physical_cpus aggregate_logical_cpus}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_vm_totals
    items = %w{aggregate_vm_memory aggregate_vm_cpus}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{ems parent_datacenter total_hosts total_direct_vms allvms_size total_miq_templates total_vms rps_size states_size}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_storage_relationships
    items = %w{ss_size sv_size fs_size se_size}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_configuration
    return nil if @record.ha_enabled.nil? && @record.ha_admit_control.nil? &&  @record.drs_enabled.nil? &&
        @record.drs_automation_level.nil? && @record.drs_migration_threshold.nil?
    items = %w{ha_enabled ha_admit_control drs_enabled drs_automation_level drs_migration_threshold}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_tags
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_aggregate_cpu_speed
    {:label => "Total CPU Resources", :value => "#{mhz_to_human_size(@record.aggregate_cpu_speed)}"}
  end

  def textual_aggregate_memory
    {:label => "Total Memory", :value => number_to_human_size(@record.aggregate_memory.megabytes, :precision => 2)}
  end

  def textual_aggregate_physical_cpus
    {:label => "Total CPUs", :value => number_with_delimiter(@record.aggregate_physical_cpus)}
  end

  def textual_aggregate_logical_cpus
    {:label => "Total Host CPU Cores", :value => number_with_delimiter(@record.aggregate_logical_cpus)}
  end

  def textual_aggregate_vm_memory
    {:label => "Total Configured Memory", :value => "#{number_to_human_size(@record.aggregate_vm_memory.megabytes, :precision => 2)} (Virtual to Real Ratio: #{@record.v_ram_vr_ratio})"}
  end

  def textual_aggregate_vm_cpus
    {:label => "Total Configured CPUs", :value => "#{number_with_delimiter(@record.aggregate_vm_cpus)} (Virtual to Real Ratio: #{@record.v_cpu_vr_ratio})"}
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_infra")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_infra_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_infra', :action => 'show', :id => ems)
    end
    h
  end

  def textual_parent_datacenter
    {:label => "Datacenter", :image => "datacenter", :value => @record.v_parent_datacenter || "None"}
  end

  def textual_total_hosts
    num = @record.total_hosts
    h = {:label => "Hosts", :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:title] = "Show all Hosts"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'hosts')
    end
    h
  end

  def textual_total_direct_vms
    num = @record.total_direct_vms
    h = {:label => "Direct VMs", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show VMs in this Cluster, but not in Resource Pools below"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_allvms_size
    num = @record.total_vms
    h = {:label => "All VMs", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show all VMs in this Cluster"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'all_vms')
    end
    h
  end

  def textual_total_miq_templates
    num = @record.total_miq_templates
    h = {:label => "All Templates", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:title] = "Show all Templates in this Cluster"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'miq_templates')
    end
    h
  end

  def textual_total_vms
    num = @record.total_vms
    h = {:label => "All VMs (Tree View)", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show tree of all VMs by Resource Pool in this Cluster"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'descendant_vms')
    end
    h
  end

  def textual_rps_size
    num = @record.number_of(:resource_pools)
    h = {:label => "Resource Pools", :image => "resource_pool", :value => num}
    if num > 0 && role_allows(:feature => "resource_pool_show_list")
      h[:title] = "Show all Resource Pools"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'resource_pools')
    end
    h
  end

  def textual_states_size
    return nil unless role_allows(:feature => "ems_cluster_drift")
    num = @record.number_of(:drift_states)
    h = {:label => "Drift History", :image => "drift", :value => (num == 0 ? "None" : num)}
    if num > 0
      h[:title] = "Show cluster drift history"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'drift_history', :id => @record)
    end
    h
  end

  def textual_ss_size
    num = @record.storage_systems.count
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :image => "ontap_storage_system", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'storage_systems')
    end
    h
  end

  def textual_sv_size
    num = @record.storage_systems.count
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'ontap_storage_volumes')
    end
    h
  end

  def textual_fs_size
    num = @record.file_shares.count
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature => "ontap_file_share_show_list")
      h[:title] = label
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'ontap_file_shares')
    end
    h
  end

  def textual_se_size
    num = @record.base_storage_extents.count
    label = ui_lookup(:tables => "cim_base_storage_extent")
    h = {:label => label, :image => "cim_base_storage_extent", :value => num}
    if num > 0 && role_allows(:feature => "cim_base_storage_extent_show_list")
      h[:title] = label
      h[:link]  = url_for(:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'storage_extents')
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

  def textual_ha_enabled
    value = @record.ha_enabled
    return nil if value.nil?
    {:label => "HA Enabled", :value => value}
  end

  def textual_ha_admit_control
    value = @record.ha_admit_control
    return nil if value.nil?
    {:label => "HA Admit Control", :value => value}
  end

  def textual_drs_enabled
    value = @record.drs_enabled
    return nil if value.nil?
    {:label => "DRS Enabled", :value => value}
  end

  def textual_drs_automation_level
    value = @record.drs_automation_level
    return nil if value.nil?
    {:label => "DRS Automation Level", :value => value}
  end

  def textual_drs_migration_threshold
    value = @record.drs_migration_threshold
    return nil if value.nil?
    {:label => "DRS Migration Threshold", :value => value}
  end
end
