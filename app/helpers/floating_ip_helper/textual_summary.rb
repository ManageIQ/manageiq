module FloatingIpHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(address type fixed_ip_address status)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems_network cloud_tenant instance network_port)
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
    @record.ext_management_system.try(:parent_manager)
  end

  def textual_ems_network
    @record.ext_management_system
  end

  def textual_instance
    # TODO(lsmola) Textual link is messed up here, it infers feature as vm_or_template_show, we need to fix that
    @record.vm
  end

  def textual_cloud_tenant
    @record.cloud_tenant
  end

  def textual_network_port
    @record.network_port
  end
end
