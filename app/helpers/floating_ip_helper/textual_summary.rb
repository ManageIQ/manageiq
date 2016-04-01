module FloatingIpHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(address type fixed_ip_address status)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems_network cloud_tenant instance)
  end

  def textual_group_tags
    %i(tags)
  end

  #
  # Items
  #

  def textual_address
    @record.address
  end

  def textual_type
    ui_lookup(:model => @record.type)
  end

  def textual_fixed_ip_address
    @record.fixed_ip_address
  end

  def textual_status
    @record.status
  end

  def textual_parent_ems_cloud
    textual_link(@record.ext_management_system.try(:parent_manager))
  end

  def textual_ems_network
    textual_link(@record.ext_management_system)
  end

  def textual_instance
    # TODO(lsmola) Textual link is messed up here, it infers feature as vm_or_template_show, we need to fix that
    textual_link(@record.vm)
  end

  def textual_cloud_tenant
    textual_link(@record.cloud_tenant)
  end
end
