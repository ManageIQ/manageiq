module CimBaseStorageExtentHelper::GraphicalSummary
  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{storage_system storage_volumes file_shares file_systems logical_disks}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_infrastructure_relationships
    items = %w{vms hosts datastores}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def graphical_storage_system
    label = ui_lookup(:table=>"ontap_storage_system")
    ss   = @item.storage_system
    h     = {:label => label , :image => "ontap_storage_system", :value =>(ss.blank? ? "None" : ss.evm_display_name)}
    if !ss.blank? && role_allows(:feature=>"ontap_storage_system_show")
      h[:link]  = link_to("", {:action => 'show', :controller=>"ontap_storage_system", :id => ss.id}, :title => "Show #{label} '#{ss.evm_display_name}'")
    end
    h
  end

  def graphical_storage_volumes
    label = ui_lookup(:tables=>"ontap_storage_volume")
    num   = @item.number_of(:storage_volumes)
    h     = {:label => label, :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature=>"ontap_storage_volume_show")
      h[:link]  = link_to("", {:action => 'show', :id => @item, :display => 'ontap_storage_volumes'}, :title => "Show all #{label}")
    end
    h
  end

  def graphical_file_shares
    label = ui_lookup(:tables=>"ontap_file_share")
    num   = @item.number_of(:file_shares)
    h     = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature=>"ontap_file_share_show")
      h[:link]  = link_to("", {:action => 'show', :id => @item, :display => 'ontap_file_shares'}, :title => "Show all #{label}")
    end
    h
  end

  def graphical_file_systems
    label = ui_lookup(:tables=>"snia_local_file_system")
    num   = @item.number_of(:file_systems)
    h     = {:label => label, :image => "snia_local_file_system", :value => num}
    if num > 0 && role_allows(:feature=>"snia_local_file_system_show")
      h[:link]  = link_to("", {:action => 'show', :id => @item, :display => 'snia_local_file_systems'}, :title => "Show all #{label}")
    end
    h
  end

  def graphical_logical_disks
    label = ui_lookup(:tables=>"ontap_logical_disk")
    num   = @item.number_of(:logical_disks)
    h     = {:label => label, :image => "ontap_logical_disk", :value => num}
    if num > 0 && role_allows(:feature=>"ontap_logical_disk_show")
      h[:link]  = link_to("", {:action => 'show', :id => @item, :display => 'ontap_logical_disks'}, :title => "Show all #{label}")
    end
    h
  end

  def graphical_vms
    label = "VMs"
    num   = @item.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @item, :display => 'vms'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_hosts
    label = "Hosts"
    num   = @item.number_of(:hosts)
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @item, :display => 'hosts'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_datastores
    label = ui_lookup(:tables=>"storages")
    num   = @item.number_of(:storages)
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @item, :display => 'storages'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end
end
