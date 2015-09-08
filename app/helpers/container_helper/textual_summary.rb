module ContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(name state reason started_at finished_at exit_code signal message last_state restart_count backing_ref command)
  end

  def textual_group_relationships
    %i(ems container_project container_replicator container_group container_node container_image)
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

  def textual_state
    @record.state
  end

  def textual_reason
    {:label => "Reason", :value => @record.reason} if @record.reason
  end

  def textual_started_at
    {:label => "Started At", :value => @record.started_at} if @record.started_at
  end

  def textual_finished_at
    {:label => "Finished At", :value => @record.finished_at} if @record.finished_at
  end

  def textual_exit_code
    {:label => "Exit Code", :value => @record.exit_code} if @record.exit_code
  end

  def textual_signal
    {:label => "Signal", :value => @record.signal} if @record.signal
  end

  def textual_message
    {:label => "Message", :value => @record.message} if @record.message
  end

  def textual_last_state
    {:label => "Last State", :value => @record.last_state}
  end

  def textual_restart_count
    @record.restart_count
  end

  def textual_backing_ref
    {:label => "Backing Ref (Container ID)", :value => @record.backing_ref}
  end

  def textual_command
    {:label => "Command", :value => @record.container_definition.command} if @record.container_definition.command
  end
end
