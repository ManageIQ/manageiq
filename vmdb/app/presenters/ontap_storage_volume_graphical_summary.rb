class OntapStorageVolumeGraphicalSummaryPresenter < StorageGraphicalSummaryPresenter
  #
  # Groups
  #
  def graphical_group_relationships
    items = %w{storage_system base_storage_extents}
    call_items(items)
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
end
