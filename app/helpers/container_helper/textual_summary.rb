module ContainerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(image name state restart_count backing_ref image_ref)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w(ems)
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

  def textual_backing_ref
    {:label => "Backing Ref (Container ID)", :value => @record.backing_ref}
  end

  def textual_image_ref
    {:label => "Image Ref (Image ID)", :value => @record.image_ref}
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_container")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_container_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_container', :action => 'show', :id => ems)
    end
    h
  end
end
