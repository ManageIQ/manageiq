module ContainerProjectHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name display_name creation_timestamp resource_version)
  end

  def textual_group_relationships
    %i(ems container_routes container_services container_replicators container_groups)
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_display_name
    {:label => "Display Name", :value => @record.display_name}
  end

  def textual_creation_timestamp
    {:label => "Creation Timestamp", :value => format_timezone(@record.creation_timestamp)}
  end

  def textual_resource_version
    {:label => "Resource Version", :value => @record.resource_version}
  end
end
