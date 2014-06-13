module OntapStorageVolumeHelper::GraphicalSummary
  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{storage_system base_storage_extents}
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
    ss   = @record.storage_system
    h     = {:label => label , :image => "ontap_storage_system", :value =>ss.evm_display_name}
    if role_allows(:feature=>"ontap_storage_system_show")
      h[:link]  = link_to("", {:action => 'show', :controller=>"ontap_storage_system", :id => ss.id}, :title => "Show #{label} '#{ss.evm_display_name}'")
    end
    h
  end

  def graphical_base_storage_extents
    label = ui_lookup(:tables=>"cim_base_storage_extent")
    num   = @record.base_storage_extents_size
    h     = {:label => label, :image => "cim_base_storage_extent", :value => num}
    if num > 0 && role_allows(:feature=>"cim_base_storage_extent_show")
      h[:link]  = link_to("",{:action => 'cim_base_storage_extents', :id => @record, :db => controller.controller_name}, :title => "Show all #{label}")
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

  def graphical_hosts
    label = "Hosts"
    num   = @record.hosts_size
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'hosts'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_datastores
    label = ui_lookup(:tables=>"storages")
    num   = @record.storages_size
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'storages'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end
end
