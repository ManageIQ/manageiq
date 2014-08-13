class OntapLogicalDiskTextualSummaryPresenter < StorageTextualSummaryPresenter
  #
  # Groups
  #
  def textual_group_properties
    items = %w{name element_name caption zone_name description operational_status_str
                health_state_str enabled_state data_redundancy system_name number_of_blocks block_size consumable_blocks
                device_id extent_status delta_reservation no_single_point_of_failure? is_based_on_underlying_redundancy?
                primordial? last_update_status_str}
    call_items(items)
  end

  def textual_group_capacity_data
    items = %w{state size_available size_used size_total snapshot_blocks_reserved compressed_data
                compression_saved_percentage dedup_percent_saved dedup_size_saved dedup_size_shared
                disk_count files_total files_used is_compression_enabled is_inconsistent is_invalid
                is_unrecoverable}
    call_items(items)
  end

  def textual_group_relationships
    items = %w{storage_system file_shares file_system base_storage_extents}
    call_items(items)
  end


  #
  # Items
  #
  def textual_caption
    {:label => "Caption", :value => @record.caption}
  end

  def textual_description
    {:label => "Description", :value => @record.description}
  end

  def textual_operational_status_str
    {:label => "Operational Status", :value => @record.operational_status_str}
  end

  def textual_health_state_str
    {:label => "Health State", :value => @record.health_state_str}
  end

  def textual_enabled_state
    {:label => "Enabled State", :value => @record.enabled_state}
  end

  def textual_data_redundancy
    {:label => "Data Redundancy", :value => @record.data_redundancy}
  end

  def textual_system_name
    {:label => "System Name", :value => @record.system_name}
  end

  def textual_number_of_blocks
    {:label => "Number of Blocks", :value => number_with_delimiter(@record.number_of_blocks,:delimiter=>',')}
  end

  def textual_block_size
    {:label => "Block Size", :value => @record.block_size}
  end

  def textual_consumable_blocks
    {:label => "Consumable Blocks", :value => number_with_delimiter(@record.consumable_blocks,:delimiter=>',')}
  end

  def textual_device_id
    {:label => "Device ID", :value => @record.device_id}
  end

  def textual_extent_status
    #TODO: extent_status is being returned as array, without .to_s it shows 0 0 in two lines with a link.
    {:label => "Extent Status", :value => @record.extent_status.to_s}
  end

  def textual_delta_reservation
    {:label => "Delta Reservation", :value => @record.delta_reservation}
  end

  def textual_no_single_point_of_failure?
    {:label => "No Single Point Of Failure", :value => @record.no_single_point_of_failure?}
  end

  def textual_is_based_on_underlying_redundancy?
    {:label => "Based On Underlying Redundancy", :value => @record.is_based_on_underlying_redundancy?}
  end

  def textual_primordial?
    {:label => "Primordial", :value => @record.primordial?}
  end

  def textual_last_update_status_str
    {:label => "Last Update Status", :value => @record.last_update_status_str}
  end

  def textual_state
    {:label => "State", :value => @record.state}
  end

  def textual_size_available
    {:label => "Size Available", :value => number_to_human_size(@record.size_available,:precision=>2)}
  end

  def textual_size_used
    {:label => "Size Used", :value => number_to_human_size(@record.size_used,:precision=>2)}
  end

  def textual_size_total
    {:label => "Size Total", :value => number_to_human_size(@record.size_total,:precision=>2)}
  end

  def textual_snapshot_blocks_reserved
    {:label => "Snapshot Blocks Reserved", :value => number_with_delimiter(@record.snapshot_blocks_reserved,:delimiter=>',')}
  end

  def textual_compressed_data
    {:label => "Compressed Data", :value => @record.compressed_data}
  end

  def textual_compression_saved_percentage
    {:label => "Compression Saved Percentage", :value => @record.compression_saved_percentage}
  end

  def textual_dedup_percent_saved
    {:label => "Dedup Percent Saved", :value => @record.dedup_percent_saved}
  end

  def textual_dedup_size_saved
    {:label => "Dedup Size Saved", :value => @record.dedup_size_saved}
  end

  def textual_dedup_size_shared
    {:label => "Dedup Size Shared", :value => @record.dedup_size_shared}
  end

  def textual_disk_count
    {:label => "Disk Count", :value => @record.disk_count}
  end

  def textual_files_total
    {:label => "Total Files", :value => @record.files_total}
  end

  def textual_files_used
    {:label => "Used Files", :value => @record.files_used}
  end

  def textual_is_compression_enabled
    {:label => "Is Compression Enabled", :value => @record.is_compression_enabled}
  end

  def textual_is_inconsistent
    {:label => "Is Inconsistent", :value => @record.is_inconsistent}
  end

  def textual_is_invalid
    {:label => "Is Invalid", :value => @record.is_invalid}
  end

  def textual_is_unrecoverable
    {:label => "Is Unrecoverable", :value => @record.is_unrecoverable}
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

  def textual_file_shares
    label = ui_lookup(:tables => "ontap_file_share")
    num   = @record.file_shares_size
    h = {:label => label, :image => "ontap_file_share", :value => num}
    if num > 0 && role_allows(:feature => "ontap_file_share_show")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => 'ontap_logical_disk', :action => 'show', :id => @record, :display => 'ontap_file_share')
    end
    h
  end

  def textual_file_system
    label = ui_lookup(:table=>"snia_local_file_system")
    lfs   = @record.file_system
    h = {:label => label, :image => "snia_local_file_system", :value =>(lfs.blank? ? "None" : lfs.evm_display_name)}
    if !lfs.blank? && role_allows(:feature=>"snia_local_file_system_show")
      h[:title] = "Show #{label} '#{lfs.evm_display_name}'"
      h[:link]  = url_for(:db => controller.controller_name, :action => 'snia_local_file_systems', :id => @record, :show=>lfs.id)
    end
    h
  end


  def textual_base_storage_extents
    label = ui_lookup(:tables=>"cim_base_storage_extent")
    num   = @record.base_storage_extents_size
    h     = {:label => label, :image => "cim_base_storage_extent", :value => num}
    if num > 0 && role_allows(:feature=>"cim_base_storage_extent_show")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:controller => 'ontap_logical_disk', :action => 'show', :id => @record, :display => 'cim_base_storage_extents')
    end
    h
  end
end