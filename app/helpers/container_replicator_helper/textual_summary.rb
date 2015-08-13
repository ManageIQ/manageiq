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

  def textual_replicas
    {:label => "Number of replicas", :value => @record.replicas}
  end

  def textual_current_replicas
    {:label => "Number of current replicas", :value => @record.current_replicas}
  end
end
