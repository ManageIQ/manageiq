module ResourcePoolHelper::GraphicalSummary
  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{parent_datacenter parent_cluster parent_host direct_vms all_vms all_vms_tree resource_pools}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_parent_datacenter
    value = @record.v_parent_datacenter
    {:label => "Parent Datacenter:", :image => "datacenter", :value => (value || "None")}
  end

  def graphical_parent_cluster
    parent_cluster = @record.parent_cluster
    h = {:label => "Parent Cluster", :image => "ems_cluster", :value => (parent_cluster.nil? ? "None" : parent_cluster.name)}
    if parent_cluster && role_allows(:feature=>"ems_cluster_show")
       h[:link]  = link_to("", {:controller => 'ems_cluster', :action => 'show', :id => parent_cluster, :onclick => "return miqCheckForChanges()"}, :title => "Show Parent Cluster '#{parent_cluster.name}'")
    end
    h
  end

  def graphical_parent_host
    parent_host = @record.parent_host
    h = {:label => "Parent Host", :image => "host", :value => (parent_host.nil? ? "None" : parent_host.name.truncate(13))}
    if parent_host && role_allows(:feature => "host_show")
      h[:link] = link_to("", {:controller => 'host', :action => 'show', :id => parent_host}, :title => "Show Parent Host '#{parent_host.name}'")
    end
    h
  end

  def graphical_direct_vms
    num = @record.v_direct_vms
    h = {:label => "Direct VMs", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'vms'}, :title => "Show VMs in this Resource Pool, but not in Resource Pools below")
    end
    h
  end

  def graphical_all_vms
    num = @record.total_vms
    h = {:label => "All VMs", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'all_vms'}, :title => "Show all VMs in this Resource Pool")
    end
    h
  end

  def graphical_all_vms_tree
    num = @record.total_vms
    h = {:label => "All VMs (Tree View)", :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'descendant_vms'}, :title => "Show tree of all VMs in this Resource Pool")
    end
    h
  end

  def graphical_resource_pools
    num = @record.number_of(:resource_pools)
    h = {:label => "Resource Pool ", :image => "resource_pool", :value => num}
    if num > 0 && role_allows(:feature => "resource_pool_show_list")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'resource_pools'}, :title => "Show all Resource Pools")
    end
    h
  end

end
