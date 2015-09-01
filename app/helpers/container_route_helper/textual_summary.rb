module ContainerRouteHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name creation_timestamp resource_version)
  end

  def textual_group_relationships
    %i(ems container_project container_service)
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
end
