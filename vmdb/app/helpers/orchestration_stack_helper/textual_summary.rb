module OrchestrationStackHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_relationships
    items = %w(ems_cloud orchestration_template instances security_groups cloud_networks parameters outputs resources)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_tags
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_ems_cloud
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_cloud")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_cloud_show")
      h[:title] = "Show this Orchestration Stack's #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_cloud', :action => 'show', :id => ems)
    end
    h
  end

  def textual_orchestration_template
    template = @record.orchestration_template
    return nil if template.nil?
    label = ui_lookup(:table => "orchestration_template")
    {:label => label, :image => "orchestration_template", :value => template.name}
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @orchestration_stack, :display => 'instances')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_security_groups
    label = ui_lookup(:tables => "security_group")
    num   = @record.number_of(:security_groups)
    h     = {:label => label, :image => "security_group", :value => num}
    if num > 0 && role_allows(:feature => "security_group_show_list")
      h[:link]  = url_for(:action => 'show', :id => @orchestration_stack, :display => 'security_groups')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_cloud_networks
    label = ui_lookup(:tables => "cloud_network")
    num   = @record.number_of(:cloud_networks)
    h     = {:label => label, :image => "cloud_network", :value => num}
    if num > 0
      h[:link]  = url_for(:controller => controller.controller_name, :action => 'cloud_networks', :id => @record)
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_parameters
    label = ui_lookup(:tables => "parameter")
    num   = @record.number_of(:parameters)
    h     = {:label => label, :image => "parameter", :value => num}
    if num > 0
      # h[:link]  = url_for(:controller => controller.controller_name, :action => 'parameters', :id => @record)
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_outputs
    label = ui_lookup(:tables => "output")
    num   = @record.number_of(:outputs)
    h     = {:label => label, :image => "output", :value => num}
    if num > 0 && role_allows(:feature => "outputs_show_list")
      # h[:link]  = url_for(:controller => controller.controller_name, :action => 'outputs', :id => @record)
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_resources
    label = ui_lookup(:tables => "resource")
    num   = @record.number_of(:resources)
    h     = {:label => label, :image => "resource", :value => num}
    if num > 0
      # h[:link]  = url_for(:controller => controller.controller_name, :action => 'resources', :id => @record)
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.blank?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, _| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned} }
    end
    h
  end
end
