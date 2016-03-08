module CimBaseStorageExtentHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name vendor zone_name description operational_status_str health_state_str enabled_state
       system_name number_of_blocks block_size consumable_blocks device_id extent_status
       primordial? last_update_status_str)
  end

  #
  # Items
  #

  def textual_name
    {:label => _("Name"), :value => @item.evm_display_name}
  end

  def textual_vendor
    {:label => _("Vendor"), :value => @item.vendor}
  end

  def textual_zone_name
    {:label => _("Zone Name"), :value => @item.zone_name}
  end

  def textual_description
    {:label => _("Description"), :value => @item.description}
  end

  def textual_operational_status_str
    {:label => _("Operational Status"), :value => @item.operational_status_str}
  end

  def textual_health_state_str
    {:label => _("Health State"), :value => @item.health_state_str}
  end

  def textual_enabled_state
    {:label => _("Enabled State"), :value => @item.enabled_state}
  end

  def textual_system_name
    {:label => _("System Name"), :value => @item.system_name}
  end

  def textual_number_of_blocks
    {:label => _("Number of Blocks"), :value => number_with_delimiter(@item.number_of_blocks, :delimiter => ',')}
  end

  def textual_block_size
    {:label => _("Block Size"), :value => @item.block_size}
  end

  def textual_consumable_blocks
    {:label => _("Consumable Blocks"), :value => number_with_delimiter(@item.consumable_blocks, :delimiter => ',')}
  end

  def textual_device_id
    {:label => _("Device ID"), :value => @item.device_id}
  end

  def textual_extent_status
    # TODO: extent_status is being returned as array, without .to_s it shows 0 0 in two lines with a link.
    {:label => _("Extent Status"), :value => @item.extent_status.to_s}
  end

  def textual_primordial?
    {:label => _("Primordial"), :value => @item.primordial?}
  end

  def textual_last_update_status_str
    {:label => _("Last Update Status"), :value => @item.last_update_status_str}
  end
end
