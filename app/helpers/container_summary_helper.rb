module ContainerSummaryHelper
  # TODO: most of these methods can be further simplified in the future
  #       maybe using define_method and pluralize.

  def textual_ems
    textual_single_relationship(
      :ext_management_system,
      :name,
      "vendor-#{@record.ext_management_system.image_name}",
      "ems_container_show",
      "ems_container"
    )
  end

  def textual_container_project
    textual_single_relationship(
      :container_project,
      :name,
      "container_project",
      "container_project_show",
    )
  end

  def textual_container_projects
    textual_multiple_relationship(
      :container_projects,
      "container_project",
      "container_project_show_list"
    )
  end

  def textual_container_routes
    textual_multiple_relationship(
      :container_routes,
      "container_route",
      "container_route_show_list"
    )
  end

  def textual_container_services
    textual_multiple_relationship(
      :container_services,
      "container_service",
      "container_service_show_list"
    )
  end

  def textual_container_replicators
    textual_multiple_relationship(
      :container_replicators,
      "container_replicator",
      "container_replicator_show_list"
    )
  end

  def textual_container_groups
    textual_multiple_relationship(
      :container_groups,
      "container_group",
      "container_group_show_list"
    )
  end

  def textual_containers
    textual_multiple_relationship(
      :containers,
      "container",
      "containers",  # should it be container_show_list?
    )
  end

  def textual_container_nodes
    textual_multiple_relationship(
      :container_nodes,
      "container_node",
      "container_node_show_list",
    )
  end

  def textual_container_node
    textual_single_relationship(
      :container_node,
      :name,
      "container_node",
      "container_node_show",
    )
  end

  private

  def textual_single_relationship(entity, attribute, image, feature, controller = nil)
    controller ||= entity.to_s

    label = ui_lookup(:table => controller)
    rel_entity = @record.send(entity)

    return if rel_entity.nil?
    rel_value = rel_entity.send(attribute)

    h = {:label => label, :image => image, :value => rel_value}

    if role_allows(:feature => feature)
      h[:link] = url_for(:controller => controller, :action => 'show', :id => rel_entity)
      h[:title] = "Show #{label} '#{rel_value}'"
    end

    h
  end

  def textual_multiple_relationship(entity, image, feature)
    label = ui_lookup(:tables => entity.to_s)
    rel_num = @record.number_of(entity)

    h = {:label => label, :image => image, :value => rel_num.to_s}

    if rel_num > 0 && role_allows(:feature => feature)
      h[:link] = url_for(:action => 'show', :id => @record, :display => entity)
      h[:title] = "Show all #{label}"
    end

    h
  end
end
