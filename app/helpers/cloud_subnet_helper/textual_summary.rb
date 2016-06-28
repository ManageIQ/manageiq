module CloudSubnetHelper::TextualSummary
  include TextualMixins::TextualName
  #
  # Groups
  #

  def textual_group_properties
    %i(name type cidr gateway network_protocol dns_nameservers_show allocation_pools host_routes ip_version)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems_network cloud_tenant availability_zone instances cloud_network network_router)
  end

  def textual_group_tags
    %i(tags)
  end

  #
  # Items
  #
  def textual_type
    ui_lookup(:model => @record.type)
  end

  def textual_cidr
    @record.cidr
  end

  def textual_gateway
    @record.gateway
  end

  def textual_network_protocol
    @record.network_protocol
  end

  def textual_dns_nameservers_show
    @record.dns_nameservers_show
  end

  def textual_allocation_pools
    @record.allocation_pools.map { |x| "<#{x['start']}, #{x['end']}>" }.join(", ") if @record.allocation_pools
  end

  def textual_host_routes
    @record.host_routes.map { |x| "next_hop: #{x['next_hop']}, destination: #{x['destination']}" }.join(" | ") if @record.host_routes
  end

  def textual_ip_version
    @record.ip_version
  end

  def textual_parent_ems_cloud
    @record.ext_management_system.try(:parent_manager)
  end

  def textual_ems_network
    @record.ext_management_system
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_cloud_network
    @record.cloud_network
  end

  def textual_cloud_tenant
    @record.cloud_tenant
  end

  def textual_network_router
    @record.network_router
  end

  def textual_availability_zone
    @record.availability_zone
  end
end
