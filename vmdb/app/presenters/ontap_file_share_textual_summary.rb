class OntapFileShareTextualSummaryPresenter < StorageTextualSummaryPresenter
  #
  # Groups
  #
  def textual_group_properties
    items = %w{name element_name caption zone_name operational_status_str instance_id sharing_directory? last_update_status_str}
    call_items(items)
  end

  def textual_group_relationships
    items = %w{logical_disk storage_system local_file_system base_storage_extents}
    call_items(items)
  end


  #
  # Items
  #
  def textual_caption
    {:label => "Caption", :value => @record.caption}
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
end