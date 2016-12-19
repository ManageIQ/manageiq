module FloatingIpHelper::TextualSummary
  include TextualMixins::TextualEmsNetwork
  include TextualMixins::TextualGroupTags
  #
  # Groups
  #

  def textual_group_properties
    %i(address type fixed_ip_address status)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems_network cloud_tenant instance network_port)
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

  def textual_instance
    label    = ui_lookup(:table => "vm_cloud")
    instance = @record.vm
    h        = {:label => label, :icon => "pficon pficon-virtual-machine"}
    if instance && role_allows?(:feature => "vm_show")
      h[:value] = instance.name
      h[:link]  = url_for(:controller => 'vm_cloud', :action => 'show', :id => instance.id)
      h[:title] = _("Show %{label}") % {:label => label}
    end
    h
  end

  def textual_cloud_tenant
    @record.cloud_tenant
  end

  def textual_network_port
    @record.network_port
  end
end
