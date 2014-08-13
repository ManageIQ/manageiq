class OntapStorageSystemTextualSummaryPresenter < StorageTextualSummaryPresenter
  #
  # Groups
  #
  def textual_group_properties
    items = %w{name element_name vendor zone_name description operational_status health_state other_identifying_info last_update_status}
    call_items(items)
  end

  def textual_group_relationships
    items = %w{storage_volumes hosted_file_shares local_file_systems logical_disks base_storage_extents}
    call_items(items)
  end


  #
  # Items
  #
  def textual_vendor
    {:label => "Vendor", :value => @record.vendor}
  end

  def textual_description
    {:label => "Description", :value => @record.description}
  end

  def textual_operational_status
    {:label => "Operational Status", :value => @record.operational_status_str}
  end

  def textual_health_state
    {:label => "Health State", :value => @record.health_state_str}
  end

  def textual_other_identifying_info
    {:label => "Other Identifying Info", :value => @record.other_identifying_info.join(', ')}
  end

  def textual_last_update_status
    {:label => "Last Update Status", :value => @record.last_update_status_str}
  end

  def textual_storage_volumes
    label = ui_lookup(:tables => "ontap_storage_volume")
    num   = @record.storage_volumes_size
    h     = {:label => label , :image => "ontap_storage_volume", :value => num}
    if num > 0 && role_allows(:feature => "ontap_storage_volume_show")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => 'ontap_storage_system', :action => 'show', :id => @record, :display => 'ontap_storage_volume')
    end
    h
  end

  def textual_hosted_file_shares
    label = ui_lookup(:tables => "ontap_file_share")
    num   = @record.hosted_file_shares_size
    h = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature => "ontap_file_share_show")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => 'ontap_storage_system', :action => 'show', :id => @record, :display => 'ontap_file_share')
    end
    h
  end

  def textual_local_file_systems
    label = ui_lookup(:tables=>"snia_local_file_system")
    num   = @record.local_file_systems_size
    h = {:label => label, :image => "snia_local_file_system", :value => num}
    if num > 0 && role_allows(:feature=>"snia_local_file_system_show")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'snia_local_file_systems', :id => @record, :db => controller.controller_name)
    end
    h
  end

  def textual_logical_disks
    label = ui_lookup(:tables=>"ontap_logical_disk")
    num   = @record.logical_disks_size
    h = {:label => label, :image => "ontap_logical_disk", :value => num}
    if num > 0 && role_allows(:feature=>"ontap_logical_disk_show")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => 'ontap_storage_system', :action => 'show', :id => @record, :display => 'ontap_logical_disks')
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