module ContainerRouteHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name creation_timestamp resource_version host_name path)
  end

  def textual_group_relationships
    %i(ems container_project container_service container_groups container_nodes)
  end

  def textual_group_smart_management
    items = %w(tags)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    @record.name
  end

  def textual_creation_timestamp
    format_timezone(@record.creation_timestamp)
  end

  def textual_resource_version
    @record.resource_version
  end

  def textual_host_name
    @record.host_name
  end

  def textual_path
    @record.path
  end
end
