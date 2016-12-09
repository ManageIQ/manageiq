module LoadBalancerHelper::TextualSummary
  include TextualMixins::TextualEmsNetwork
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName
  #
  # Groups
  #

  def textual_group_properties
    %i(name type description listeners health_checks)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems_network cloud_tenant instances)
  end

  #
  # Items
  #

  def textual_type
    ui_lookup(:model => @record.type)
  end

  def textual_description
    @record.description
  end

  def textual_listeners
    @record.load_balancer_listeners.map do |x|
      "Load Balancer"\
        " #{LoadBalancerHelper.display_protocol_port_range(x.load_balancer_protocol, x.load_balancer_port_range)}"\
        ", Instance"\
        " #{LoadBalancerHelper.display_protocol_port_range(x.instance_protocol, x.instance_port_range)}"
    end.join(" | ") if @record.load_balancer_listeners
  end

  def textual_health_checks
    @record.load_balancer_health_checks.map do |x|
      "#{x.protocol}:#{x.port}/#{x.url_path}"
    end.join("\n") if @record.load_balancer_health_checks
  end

  def textual_parent_ems_cloud
    @record.ext_management_system.try(:parent_manager)
  end

  def textual_cloud_tenant
    @record.cloud_tenant
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "100/vm.png", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end
end
