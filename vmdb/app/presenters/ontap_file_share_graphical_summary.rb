class OntapFileShareGraphicalSummaryPresenter < GraphicalSummaryPresenter
  #
  # Groups
  #
  def graphical_group_relationships
    items = %w{logical_disk storage_system local_file_system base_storage_extents}
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

  def graphical_local_file_system
    label = ui_lookup(:table=>"snia_local_file_system")
    lfs   = @record.file_system
    h     = {:label => label , :image => "snia_local_file_system", :value =>(lfs.blank? ? "None" : lfs.evm_display_name)}
    if !lfs.blank? && role_allows(:feature=>"snia_local_file_system_show")
      h[:link]  = link_to("", {:action => 'show', :controller=>"snia_local_file_system", :id => lfs.id}, :title => "Show #{label} '#{lfs.evm_display_name}'")
    end
    h
  end

  def graphical_logical_disk
    label = ui_lookup(:table=>"ontap_logical_disk")
    ld   = @record.logical_disk
    h     = {:label => label , :image => "ontap_logical_disk", :value =>(ld.blank? ? "None" : ld.evm_display_name)}
    if !ld.blank? && role_allows(:feature=>"ontap_logical_disk_show")
      h[:link]  = link_to("", {:action => 'show', :controller=>"ontap_logical_disk", :id => ld.id}, :title => "Show #{label} '#{ld.evm_display_name}'")
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
