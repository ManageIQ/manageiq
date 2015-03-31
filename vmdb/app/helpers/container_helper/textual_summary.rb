module ContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(image name state restart_count container_id)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_image
    {:label => "Image", :value => @record.image}
  end

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_state
    {:label => "State", :value => @record.state}
  end

  def textual_restart_count
    {:label => "Restart Count", :value => @record.restart_count}
  end

  def textual_container_id
    {:label => "Container ID", :value => @record.container_id}
  end

  def textual_image
    {:label => "image", :value => @record.image}
  end
end
