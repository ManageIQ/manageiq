module ContainerGroupHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(namespace name creation_timestamp resource_version restart_policy dns_policy)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w(ems containers)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_namespace
    {:label => "Namespace", :value => @record.namespace}
  end

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_creation_timestamp
    {:label => "Creation Timestamp", :value => format_timezone(@record.creation_timestamp)}
  end

  def textual_resource_version
    {:label => "Resource Version", :value => @record.resource_version}
  end

  def textual_restart_policy
    {:label => "Restart Policy", :value => @record.restart_policy}
  end

  def textual_dns_policy
    {:label => "DNS Policy", :value => @record.dns_policy}
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_container")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_container_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_container', :action => 'show', :id => ems)
    end
    h
  end

  def textual_containers
    num_of_containers = @record.number_of(:containers)
    label = ui_lookup(:tables => "containers")
    h     = {:label => label, :image => "container", :value => num_of_containers}
    if num_of_containers > 0 && role_allows(:feature => "containers")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'containers')
      h[:title] = "View #{label}"
    end
    h
  end
end
