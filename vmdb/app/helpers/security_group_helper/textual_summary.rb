module SecurityGroupHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w{description type}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{ems_cloud instances}
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
    h = {:label => label, :image => "vendor-#{ems.emstype.downcase}", :value => ems.name}
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

end
