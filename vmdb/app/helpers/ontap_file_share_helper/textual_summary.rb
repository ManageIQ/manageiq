module OntapFileShareHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{name element_name caption zone_name operational_status_str instance_id sharing_directory? last_update_status_str}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{logical_disk storage_system local_file_system base_storage_extents}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_infrastructure_relationships
    items = %w{vms hosts datastores}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_smart_management
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @record.evm_display_name}
  end

  def textual_element_name
    {:label => "Element Name", :value => @record.element_name}
  end

  def textual_caption
    {:label => "Caption", :value => @record.caption}
  end

  def textual_zone_name
    {:label => "Zone Name", :value => @record.zone_name}
  end

  def textual_operational_status_str
    {:label => "Operational Status", :value => @record.operational_status_str}
  end

  def textual_instance_id
    {:label => "Instance ID", :value => @record.instance_id}
  end

  def textual_sharing_directory?
    {:label => "Sharing Directory", :value => @record.sharing_directory?}
  end

  def textual_last_update_status_str
    {:label => "Last Update Status", :value => @record.last_update_status_str}
  end

  def textual_storage_system
    label = ui_lookup(:table => "ontap_storage_system")
    ss   = @record.storage_system
    h     = {:label => label , :image => "ontap_storage_system", :value =>(ss.blank? ? "None" : ss.evm_display_name)}
    if !ss.blank? && role_allows(:feature => "ontap_storage_system_show")
      h[:title] = "Show #{label} '#{ss.evm_display_name}'"
      h[:link]  = url_for(:controller => 'ontap_storage_system', :action => 'show', :id => ss.id)
    end
    h
  end

  def textual_local_file_system
    label = ui_lookup(:table => "snia_local_file_system")
    lfs   = @record.file_system
    h     = {:label => label , :image => "snia_local_file_system", :value =>(lfs.blank? ? "None" : lfs.evm_display_name)}
    if !lfs.blank? && role_allows(:feature => "snia_local_file_system_show")
      h[:title] = "Show #{label} '#{lfs.evm_display_name}'"
     # h[:link]  = url_for(:controller => 'snia_local_file_system', :action => 'show', :id => lfs.id)
      h[:link]  = url_for(:action => 'snia_local_file_systems', :id => @record, :show=>lfs.id, :db => controller.controller_name)
    end
    h
  end

  def textual_logical_disk
    label = ui_lookup(:table => "ontap_logical_disk")
    ld   = @record.logical_disk
    h     = {:label => label , :image => "ontap_logical_disk", :value =>(ld.blank? ? "None" : ld.evm_display_name)}
    if !ld.blank? && role_allows(:feature => "ontap_logical_disk_show")
      h[:title] = "Show #{label} '#{ld.evm_display_name}'"
      h[:link]  = url_for(:controller => 'ontap_logical_disk', :action => 'show', :id => ld.id)
    end
    h
  end

  def textual_base_storage_extents
    label = ui_lookup(:tables=>"cim_base_storage_extent")
    num   = @record.base_storage_extents_size
    h     = {:label => label, :image => "cim_base_storage_extent", :value => num}
    if num > 0 && role_allows(:feature=>"cim_base_storage_extent_show")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'cim_base_storage_extents', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_hosts
    label = "Hosts"
    num   = @record.hosts_size
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hosts')
    end
    h
  end

  def textual_datastores
    label = ui_lookup(:tables=>"storages")
    num   = @record.storages_size
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'storages')
    end
    h
  end

  def textual_vms
    label = "VMs"
    num   = @record.vms_size
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h     = {:label => label}
    tags  = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end
end
