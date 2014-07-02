module CloudTenantHelper::GraphicalSummary
  #
  # Groups
  #
  def graphical_group_relationships
    items = %w{ems_cloud security_groups instances images}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def graphical_ems_cloud
    ems = @record.ext_management_system
    label = ui_lookup(:table => "ems_cloud")
    h = {:label => label, :image => (ems ? ems.emstype : "ems_cloud"), :value => (ems ? ems.name.truncate(13) : "None")}
    if ems && role_allows(:feature => "ems_cluster_show")
      h[:link] = link_to("", {:controller => 'ems_cloud', :action => 'show', :id => ems}, :title => "Show this Cloud Tenant's Cloud Provider '#{ems.name}'")
    end
    h
  end

  def graphical_security_groups
    label = ui_lookup(:tables => "security_groups")
    num = @record.number_of(:security_groups)
    h = {:label => label, :image => "security_group", :value => num}
    if num > 0 && role_allows(:feature => "security_group_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @cloud_tenant, :display => 'security_groups'}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_instances
    label = ui_lookup(:tables => "vm_cloud")
    num = @record.number_of(:vms)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @cloud_tenant, :display => 'instances'}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_images
    label = ui_lookup(:tables => "template_cloud")
    num = @record.number_of(:miq_templates)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @cloud_tenant, :display => 'instances'}, :title => "Show all #{label}", :onclick => "return miqCheckForChanges()")
    end
    h
  end
end
