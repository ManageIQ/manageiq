module CloudNetworkHelper::TextualSummary
  include TextualMixins::TextualEmsNetwork
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName
  #
  # Groups
  #

  def textual_group_properties
    %i(name type status)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems_network cloud_tenant instances cloud_subnets network_routers)
  end

  #
  # Items
  #
  def textual_type
    ui_lookup(:model => @record.type)
  end

  def textual_status
    @record.status
  end

  def textual_parent_ems_cloud
    @record.ext_management_system.try(:parent_manager)
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :icon => "pficon pficon-virtual-machine", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_cloud_tenant
    @record.cloud_tenant
  end

  def textual_network_routers
    @record.network_routers
  end

  def textual_cloud_subnets
    @record.cloud_subnets
  end
end
