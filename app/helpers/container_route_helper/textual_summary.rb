module ContainerRouteHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name creation_timestamp resource_version)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w(ems container_service)
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

  def textual_container_services
    num_of_container_services = @record.number_of(:container_services)
    label = ui_lookup(:tables => "container_services")
    h = {:label => label, :image => "container_service", :value => num_of_container_services}
    if  num_of_container_services > 0 && role_allows(:feature => "container_service_show")
      h[:link] = url_for(:action => 'show', :controller => 'container_routes', :display => 'container_services')
    end
    h
  end
end
