module SecurityGroupHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w{description type}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{ems_cloud instances orchestration_stack}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_firewall
    return nil if @record.firewall_rules.empty?
    @record.firewall_rules.collect do |rule|
      [
        rule.network_protocol,
        rule.host_protocol,
        rule.direction,
        rule.port,
        rule.end_port,
        (rule.source_ip_range || rule.source_security_group.try(:name) || "<None>")
      ]
    end.sort
  end

  def textual_group_tags
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_description
    {:label => "Description", :value => @record.description}
  end

  def textual_type
    {:label => "Type", :value => @record.type}
  end

  def textual_ems_cloud
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_cloud")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_cloud_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_cloud', :action => 'show', :id => ems)
    end
    h
  end

  def textual_instances
    label = ui_lookup(:tables=>"vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @security_group, :display => 'instances')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_orchestration_stack
    stack = @record.orchestration_stack
    return nil if stack.nil?
    label = ui_lookup(:table => "orchestration_stack")
    h = {:label => label, :image => "orchestration_stack", :value => stack.name}
    if role_allows(:feature => "orchestration_stack_show")
      h[:title] = "Show this Security Group's #{label} '#{stack.name}'"
      h[:link]  = url_for(:controller => 'orchestration_stack', :action => 'show', :id => stack)
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
      h[:value] = tags.sort_by { |category, _assigned| category.downcase }
                  .collect do |category, assigned|
                    {:image => "smarttag",
                     :label => category,
                     :value => assigned}
                  end
    end
    h
  end
end
