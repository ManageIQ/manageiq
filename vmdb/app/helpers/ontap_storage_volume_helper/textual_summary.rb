module OntapStorageVolumeHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{name element_name caption zone_name description operational_status_str
                health_state_str enabled_state data_redundancy system_name number_of_blocks block_size consumable_blocks
                device_id extent_status delta_reservation no_single_point_of_failure? is_based_on_underlying_redundancy?
                primordial? last_update_status_str}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{storage_system base_storage_extents}
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

  def textual_storage_system
    label = ui_lookup(:table => "ontap_storage_system")
    ss   = @record.storage_system
    h     = {:label => label , :image => "ontap_storage_system", :value => ss.evm_display_name}
    if role_allows(:feature => "ontap_storage_system_show")
      h[:title] = "Show #{label} '#{ss.evm_display_name}'"
      h[:link]  = url_for(:controller => 'ontap_storage_system', :action => 'show', :id => ss.id)
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
