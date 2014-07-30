class OntapStorageSystemGraphicalSummaryPresenter < GraphicalSummaryPresenter
  #
  # Groups
  #
  def graphical_group_relationships
    items = %w{storage_volumes hosted_file_shares local_file_systems logical_disks base_storage_extents}
    call_items(items)
  end

  #
  # Items
  #
  def graphical_storage_volumes
    label = ui_lookup(:tables=>"ontap_storage_volume")
    num   = @record.storage_volumes_size
    h     = {:label => label , :image => "ontap_storage_volume", :value =>num}
    if num > 0 && role_allows(:feature=>"ontap_storage_volume_show")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'ontap_storage_volume'}, :title => "Show all #{label}")
    end
    h
  end

  def graphical_hosted_file_shares
    label = ui_lookup(:tables=>"ontap_file_share")
    num   = @record.hosted_file_shares_size
    h     = {:label => label, :image => "ontap_file_share", :value =>num}
    if num > 0 && role_allows(:feature=>"ontap_file_share_show")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'ontap_file_share'}, :title => "Show all #{label}")
    end
    h
  end

  def graphical_local_file_systems
    label = ui_lookup(:tables=>"snia_local_file_system")
    num   = @record.local_file_systems_size
    h     = {:label => label, :image => "snia_local_file_system", :value => num}
    if num > 0 && role_allows(:feature=>"snia_local_file_system_show")
      h[:link]  = link_to("",{:action => 'snia_local_file_systems', :id => @record, :db => controller.controller_name}, :title => "Show all #{label}")
    end
    h
  end

  def graphical_logical_disks
    label = ui_lookup(:tables=>"ontap_logical_disk")
    num   = @record.logical_disks_size
    h     = {:label => label, :image => "ontap_logical_disk", :value => num}
    if num > 0 && role_allows(:feature=>"ontap_logical_disk_show")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'ontap_logical_disks'}, :title => "Show all #{label}")
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
end
