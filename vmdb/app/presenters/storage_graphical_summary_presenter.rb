class StorageGraphicalSummaryPresenter < GraphicalSummaryPresenter
  def graphical_datastores
    label = ui_lookup(:tables=>"storages")
    num   = @record.storages_size
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'storages'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_group_infrastructure_relationships
    items = %w{vms hosts datastores}
    call_items(items)
  end

  def graphical_hosts
    label = "Hosts"
    num   = @record.hosts_size
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'hosts'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_vms
    label = "VMs"
    num   = @record.vms_size
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'vms'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end
end
