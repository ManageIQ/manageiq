module CimBaseStorageExtentHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{name vendor zone_name description operational_status_str health_state_str enabled_state
                system_name number_of_blocks block_size consumable_blocks device_id extent_status
                primordial? last_update_status_str}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @item.evm_display_name}
  end

  def textual_vendor
    {:label => "Vendor", :value => @item.vendor}
  end

  def textual_zone_name
    {:label => "Zone Name", :value => @item.zone_name}
  end

  def textual_description
    {:label => "Description", :value => @item.description}
  end

  def textual_operational_status_str
    {:label => "Operational Status", :value => @item.operational_status_str}
  end

  def textual_health_state_str
    {:label => "Health State", :value => @item.health_state_str}
  end

  def textual_enabled_state
    {:label => "Enabled State", :value => @item.enabled_state}
  end

  def textual_system_name
    {:label => "System Name", :value => @item.system_name}
  end

  def textual_number_of_blocks
    {:label => "Number of Blocks", :value => number_with_delimiter(@item.number_of_blocks,:delimiter=>',')}
  end

  def textual_block_size
    {:label => "Block Size", :value => @item.block_size}
  end

  def textual_consumable_blocks
    {:label => "Consumable Blocks", :value => number_with_delimiter(@item.consumable_blocks,:delimiter=>',')}
  end

  def textual_device_id
    {:label => "Device ID", :value => @item.device_id}
  end

  def textual_extent_status
    #TODO: extent_status is being returned as array, without .to_s it shows 0 0 in two lines with a link.
    {:label => "Extent Status", :value => @item.extent_status.to_s}
  end

  def textual_primordial?
    {:label => "Primordial", :value => @item.primordial?}
  end

  def textual_last_update_status_str
    {:label => "Last Update Status", :value => @item.last_update_status_str}
  end
end
