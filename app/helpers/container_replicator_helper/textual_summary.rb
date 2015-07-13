module ContainerReplicatorHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name creation_timestamp resource_version
               replicas current_replicas)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w(ems container_project)
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
      h[:link]  = url_for(:controller => 'ems_container', :action => 'show', :id => ems)
    end
    h
  end

  def textual_container_project
    project = @record.container_project
    return nil if project.nil?
    label = ui_lookup(:table => "container_project")
    h = {:label => label, :image => "container_project", :value => project.name}
    if role_allows(:feature => "container_project_show")
      h[:title] = "Show parent #{label} '#{project.name}'"
      h[:link] = url_for(:controller => 'container_project', :action => 'show', :id => project)
    end
    h
  end

  def textual_replicas
    {:label => "Number of replicas", :value => @record.replicas}
  end

  def textual_current_replicas
    {:label => "Number of current replicas", :value => @record.current_replicas}
  end
end
