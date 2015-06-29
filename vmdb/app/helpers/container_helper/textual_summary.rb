module ContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(image name state restart_count backing_ref image_ref)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_env
    h = {:labels => [_("Name"), _("Type"), _("Value")]}
    h[:values] = @record.container_definition.container_env_vars.collect do |var|
      [
        var.name,
        (var.value.nil? ? "REFERENCE" : "VALUE"),
        (var.value.nil? ? var.field_path : {:text => var.value.truncate(40), :title => var.value})
      ]
    end
    h
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

  def textual_backing_ref
    {:label => "Backing Ref (Container ID)", :value => @record.backing_ref}
  end

  def textual_image_ref
    {:label => "Image Ref (Image ID)", :value => @record.image_ref}
  end
end
