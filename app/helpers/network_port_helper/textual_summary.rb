module NetworkPortHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name mac_address type fixed_ips)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems_network cloud_tenant instance cloud_subnets floating_ips)
  end

  def textual_group_tags
    %i(tags)
  end

  #
  # Items
  #
  def textual_name
    @record.name
  end

  def textual_mac_address
    @record.mac_address
  end

  def textual_type
    ui_lookup(:model => @record.type)
  end

  def textual_fixed_ips
    @record.cloud_subnet_network_ports.collect(&:address).join(", ") unless @record.cloud_subnet_network_ports.blank?
  end

  def textual_parent_ems_cloud
    @record.ext_management_system.try(:parent_manager)
  end

  def textual_ems_network
    @record.ext_management_system
  end

  def textual_instance
    label    = ui_lookup(:table => "vm_cloud")
    instance = @record.device
    h        = {:label => label, :image => "vm"}
    if instance && role_allows(:feature => "vm_show")
      h[:value] = instance.name
      h[:link]  = url_for(:controller => 'vm_cloud', :action => 'show', :id => instance.id)
      h[:title] = _("Show %{label}") % {:label => label}
    end
    h
  end

  def textual_cloud_tenant
    @record.cloud_tenant
  end

  def textual_cloud_subnets
    @record.cloud_subnets
  end

  def textual_floating_ips
    @record.floating_ips
  end
end
