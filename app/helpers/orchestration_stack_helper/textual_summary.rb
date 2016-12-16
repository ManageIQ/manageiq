module OrchestrationStackHelper::TextualSummary
  include TextualMixins::TextualDescription
  include TextualMixins::TextualEmsCloud
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName
  #
  # Groups
  #

  def textual_group_properties
    %i(name description type status status_reason)
  end

  def textual_group_lifecycle
    %i(retirement_date)
  end

  def textual_group_relationships
    %i(ems_cloud service parent_orchestration_stack child_orchestration_stack orchestration_template instances security_groups cloud_networks parameters outputs resources)
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

  def textual_status_reason
    @record.status_reason
  end

  def textual_retirement_date
    {:label => _("Retirement Date"),
     :icon  => "fa fa-clock-o",
     :value => (@record.retires_on.nil? ? _("Never") : @record.retires_on.strftime("%x %R %Z"))}
  end

  def textual_service
    h = {:label => _("Service"), :icon => "pficon pficon-service"}
    service = @record.service || @record.try(:root).try(:service)
    if service.nil?
      h[:value] = _("None")
    else
      h[:value] = service.name
      h[:title] = _("Show this Service")
      h[:link]  = url_for(:controller => 'service', :action => 'show', :id => service)
    end
    h
  end

  def textual_parent_orchestration_stack
    @record.parent
  end

  def textual_child_orchestration_stack
    num = @record.number_of(:children)
    if num == 1 && role_allows(:feature => "orchestration_stack_show")
      @record.children.first
    elsif num > 1 && role_allows(:feature => "orchestration_stack_show_list")
      label     = _("Child Orchestration Stacks")
      h         = {:label => label, :icon => "product product-orchestration_stack", :value => num}
      h[:link]  = url_for(:action => 'show', :id => @record.id, :display => 'children')
      h[:title] = _("Show all %{label}") % {:label => label}
      h
    end
  end

  def textual_orchestration_template
    template = @record.try(:orchestration_template)
    return nil if template.nil?
    label = ui_lookup(:table => "orchestration_template")
    h = {:label => label, :icon => "product product-template", :value => template.name}
    if role_allows?(:feature => "orchestration_templates_view")
      h[:title] = _("Show this Orchestration Template")
      h[:link] = url_for(:action => 'show', :id => @orchestration_stack, :display => 'stack_orchestration_template')
    end
    h
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :icon => "pficon pficon-virtual-machine", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @orchestration_stack, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_security_groups
    @record.security_groups
  end

  def textual_cloud_networks
    num = @record.number_of(:cloud_networks)
    return nil if num <= 0
    {:label => ui_lookup(:tables => "cloud_network"), :icon => "product product-cloud_network", :value => num}
  end

  def textual_parameters
    num   = @record.number_of(:parameters)
    h     = {:label => _("Parameters"), :icon => "product product-parameter", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'parameters', :id => @record)
      h[:title] = _("Show all parameters")
    end
    h
  end

  def textual_outputs
    num   = @record.number_of(:outputs)
    h     = {:label => _("Outputs"), :icon => "product product-output", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'outputs', :id => @record)
      h[:title] = _("Show all outputs")
    end
    h
  end

  def textual_resources
    num   = @record.number_of(:resources)
    h     = {:label => _("Resources"), :icon => "product product-resource", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'resources', :id => @record)
      h[:title] = _("Show all resources")
    end
    h
  end
end
