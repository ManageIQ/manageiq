module EmsInfraHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{infrastructure_folders folders clusters hosts datastores vms templates vdi_desktop_pools}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_infrastructure_folders
    label = "Hosts & Clusters"
    available = @ems.number_of(:ems_folders) > 0 && @ems.ems_folder_root
    h = {:label => label, :image => "hosts_and_clusters", :value => available ? "Available" : "N/A"}
    if available
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'ems_folders'}, :title => "Show #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_folders
    label = "VMs & Templates"
    available = @ems.number_of(:ems_folders) > 0 && @ems.ems_folder_root
    h = {:label => label, :image => "vms_and_templates", :value => available ? "Available" : "N/A"}
    if available
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'ems_folders', :vat => true}, :title => "Show Virtual Machines & Templates", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_clusters
    label = "Clusters"
    num = @ems.number_of(:ems_clusters)
    h = {:label => label, :image => "cluster", :value => num}
    if num > 0 && role_allows(:feature => "ems_cluster_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'ems_clusters'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_hosts
    label = "Hosts"
    num = @ems.number_of(:hosts)
    h = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'hosts'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_datastores
    label = ui_lookup(:tables=>"storages")
    num = @ems.number_of(:storages)
    h = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'storages'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_vms
    label = "VMs"
    num = @ems.number_of(:vms)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'vms'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_templates
    label = "Templates"
    num = @ems.number_of(:miq_templates)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'miq_templates'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_desktop_pools
    return nil unless get_vmdb_config[:product][:vdi]
    label = ui_lookup(:tables=>"vdi_desktop_pool")
    num = @ems.number_of(:vdi_desktop_pools)
    h = {:label => label, :image => "vdi_desktop_pool", :value => num}
    if num > 0 && role_allows(:feature => "vdi_desktop_pool_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'vdi_desktop_pool'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

end
