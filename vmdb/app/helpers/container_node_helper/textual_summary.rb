module ContainerNodeHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(name creation_timestamp resource_version)
    items.collect {|m| send("textual_#{m}")}.flatten.compact
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_creation_timestamp
    {:label => "Creation Timestamp", :value => @record.creation_timestamp}
  end

  def textual_resource_version
    {:label => "Resource Version", :value => @record.resource_version}
  end
end
