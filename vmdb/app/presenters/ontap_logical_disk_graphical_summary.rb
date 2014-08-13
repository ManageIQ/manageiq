class OntapLogicalDiskGraphicalSummaryPresenter < StorageGraphicalSummaryPresenter
  #
  # Groups
  #
  def graphical_group_relationships
    items = %w{storage_system file_shares file_system base_storage_extents}
    call_items(items)
  end

  #
  # Items
  #
  def graphical_storage_system
    label = ui_lookup(:table=>"ontap_storage_system")
    ss   = @record.storage_system
    h     = {:label => label , :image => "ontap_storage_system", :value =>(ss.blank? ? "None" : ss.evm_display_name)}
    if !ss.blank? && role_allows(:feature=>"ontap_storage_system_show")
      h[:link]  = link_to("", {:action => 'show', :controller=>"ontap_storage_system", :id => ss.id}, :title => "Show #{label} '#{ss.evm_display_name}'")
    end
    h
  end

  def graphical_file_shares
    label = ui_lookup(:tables=>"ontap_file_share")
    num   = @record.file_shares_size
    h     = {:label => label, :image => "ontap_file_share", :value =>num}
    if num > 0 && role_allows(:feature=>"ontap_file_share_show")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'ontap_file_share'}, :title => "Show all #{label}")
    end
    h
  end

  def graphical_file_system
    label = ui_lookup(:table=>"snia_local_file_system")
    lfs   = @record.file_system
    h     = {:label => label, :image => "snia_local_file_system", :value =>(lfs.blank? ? "None" : lfs.evm_display_name)}
    if !lfs.blank? && role_allows(:feature=>"snia_local_file_system_show")
      h[:link]  = link_to("",{:action => 'snia_local_file_systems', :id => @record, :show => lfs.id, :db => controller_name}, :title => "Show #{label} '#{lfs.evm_display_name}'")
    end
    h
  end

  def graphical_base_storage_extents
    label = ui_lookup(:tables=>"cim_base_storage_extent")
    num   = @record.base_storage_extents_size
    h     = {:label => label, :image => "cim_base_storage_extent", :value => num}
    if num > 0 && role_allows(:feature=>"cim_base_storage_extent_show")
      h[:link]  = link_to("", {:action => 'show', :id => @record, :display => 'cim_base_storage_extents'}, :title => "Show all #{label}")
    end
    h
  end
end
