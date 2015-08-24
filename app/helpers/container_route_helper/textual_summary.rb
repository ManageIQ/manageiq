module ContainerRouteHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name creation_timestamp resource_version)
    items.collect { |m| send("textual_#{m}") }
  end

  def textual_group_relationships
    items = %w(ems container_project container_service)
    items.collect { |m| send("textual_#{m}") }
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
end
