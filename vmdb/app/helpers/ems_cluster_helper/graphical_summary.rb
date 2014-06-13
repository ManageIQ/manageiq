module EmsClusterHelper::GraphicalSummary

  #
  # Groups
  #


  def graphical_group_relationships
    items = %w{ems datacenter total_hosts total_direct_vms allvms_size total_miq_templates total_vms rps_size states_size}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_storage_relationships
    items = %w{storage_systems storage_volumes file_shares base_storage_extents}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_infra")
    h = {:label => label, :image => ems.emstype, :value => ems.name.truncate(13)}
    if role_allows(:feature => "ems_infra_show")
      h[:link] = link_to("", {:controller => 'ems_infra', :action => 'show', :id => ems}, :title => "Show parent #{label} '#{ems.name}'", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_datacenter
    datacenter = @record.parent_datacenter
    return nil if datacenter.nil?
    {:label => "Datacenter", :image => "datacenter", :value => datacenter.name.truncate(13)}
  end

  def graphical_total_hosts
    num = @record.total_hosts
    h = {:label => "Hosts", :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link]  = link_to("", {:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'hosts'}, :title => "Show all Hosts", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_total_direct_vms
    num = @record.total_direct_vms
    h = {:label => "Direct VMs", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = link_to("",{:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'vms'}, :title => "Show all VMs in this cluster, but not in the Resource Pools below", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_allvms_size
    num = @record.total_vms
    h = {:label => "All VMs", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = link_to("",{:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'all_vms'}, :title => "Show all VMs in this Cluster", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_total_miq_templates
    num = @record.total_miq_templates
    h = {:label => "All Templates", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link]  = link_to("",{:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'miq_templates'}, :title => "Show all Templates in this Cluster", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_total_vms
    num = @record.total_vms
    h = {:label => "All VMs (Tree View)", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = link_to("",{:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'descendant_vms'}, :title => "Show tree of all VMs by Resource Pool in this Cluster", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_rps_size
    num = @record.number_of(:resource_pools)
    h = {:label => "Resource Pools", :image => "resource_pool", :value => num}
    if num > 0 && role_allows(:feature => "resource_pool_show_list")
      h[:link]  = link_to("",{:controller => 'ems_cluster', :action => 'show', :id => @record, :display => 'resource_pools'}, :title => "Show all Resource Pools", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_states_size
    return nil unless role_allows(:feature => "ems_cluster_drift")
    num = @record.number_of(:drift_states)
    h = {:label => "Drift History", :image => "drift", :value => (num == 0 ? "None" : num)}
    if num > 0
      h[:link]  = link_to("",{:controller => 'ems_cluster', :action => 'drift_history', :id => @record}, :title => "Show Cluster drift history")
    end
    h
  end

  def graphical_storage_systems
    num = @record.number_of(:storage_systems)
    label = ui_lookup(:tables => "ontap_storage_system")
    h = {:label => label, :image => "ontap_storage_system", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_system_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "storage_systems"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_storage_volumes
    num = @record.number_of(:storage_volumes)
    label = ui_lookup(:tables => "ontap_storage_volume")
    h = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_volume_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_storage_volumes"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_file_shares
    num = @record.number_of(:file_shares)
    label = ui_lookup(:tables => "ontap_file_share")
    h = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature => "ontap_file_share_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "ontap_file_shares"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_base_storage_extents
    num = @record.number_of(:base_storage_extents)
    label = ui_lookup(:tables => "cim_base_storage_extent")
    h = {:label => label, :image => "cim_base_storage_extent", :value => num}
    if num > 0 && role_allows(:feature => "cim_base_storage_extent_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => "storage_extents"}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

end
