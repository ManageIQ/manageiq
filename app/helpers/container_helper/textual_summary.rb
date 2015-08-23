module ContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name state restart_count backing_ref command)
  end

  def textual_group_relationships
    %i(ems container_project container_replicator container_group container_node container_image)
  end

  #
  # Items
  #

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_state
    {:label => "State", :value => @record.state}
  end

  def textual_restart_count
    {:label => "Restart Count", :value => @record.restart_count}
  end

  def textual_backing_ref
    {:label => "Backing Ref (Container ID)", :value => @record.backing_ref}
  end

  def textual_command
    {:label => "Command", :value => @record.container_definition.command} if @record.container_definition.command
  end
end
