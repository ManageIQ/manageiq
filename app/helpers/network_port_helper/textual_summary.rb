module NetworkPortHelper::TextualSummary
  include TextualMixins::TextualEmsNetwork
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName
  #
  # Groups
  #

  def textual_group_properties
    %i(name mac_address type device_owner floating_ip_addresses fixed_ip_addresses)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems_network cloud_tenant instance cloud_subnets floating_ips host)
  end

  #
  # Items
  #
  def textual_mac_address
    @record.mac_address
  end

  def textual_type
    ui_lookup(:model => @record.type)
  end

  def textual_device_owner
    @record.device_owner
  end

  def textual_fixed_ip_addresses
    @record.fixed_ip_addresses.join(", ") if @record.fixed_ip_addresses
  end

  def textual_floating_ip_addresses
    @record.floating_ip_addresses.join(", ") if @record.floating_ip_addresses
  end

  def textual_parent_ems_cloud
    @record.ext_management_system.try(:parent_manager)
  end

  def textual_instance
    label    = ui_lookup(:table => "vm_cloud")
    instance = @record.device
    h        = nil
    if instance && role_allows?(:feature => "vm_show")
      h = {:label => label, :image => "100/vm.png"}
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

  def textual_host
    return nil unless @record.device_type == "Host"
    {:image => "100/host.png", :value => @record.device, :link => url_for(:controller => "host",
                                                                  :action     => "show",
                                                                  :id         => @record.device.id)}
  end
end
