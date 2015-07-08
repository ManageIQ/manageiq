module ContainerProjectHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name creation_timestamp resource_version)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w(ems container_routes container_services container_replicators container_groups)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_creation_timestamp
    {:label => "Creation Timestamp", :value => format_timezone(@record.creation_timestamp)}
  end

  def textual_resource_version
    {:label => "Resource Version", :value => @record.resource_version}
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_container")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_container_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link] = url_for(:controller => 'ems_container', :action => 'show', :id => ems)
    end
    h
  end

  def textual_container_routes
    count_of_routes = @record.number_of(:container_routes)
    label = ui_lookup(:tables => "container_routes")
    h = {:label => label, :image => "container_route", :value => count_of_routes}
    if count_of_routes > 0 && role_allows(:feature => "container_route_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'container_routes')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_container_services
    count_of_services = @record.number_of(:container_services)
    label = "Container Services"
    h     = {:label => label, :image => "container_service", :value => count_of_services}
    if count_of_services > 0 && role_allows(:feature => "container_service_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'container_services')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_container_groups
    count_of_groups = @record.number_of(:container_groups)
    label = "Container Groups"
    h     = {:label => label, :image => "container_group", :value => count_of_groups}
    if count_of_groups > 0 && role_allows(:feature => "container_group_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'container_groups')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_container_replicators
    count_of_replicators = @record.number_of(:container_replicators)
    label = ui_lookup(:tables => "container_replicators")
    h     = {:label => label, :image => "container_replicator", :value => count_of_replicators}
    if count_of_replicators > 0 && role_allows(:feature => "container_replicator_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'container_replicators')
      h[:title] = "Show all #{label}"
    end
    h
  end
end
