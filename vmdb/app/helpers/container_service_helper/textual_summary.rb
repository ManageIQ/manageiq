module ContainerServiceHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(namespace port)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w(ems)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end
  #
  # Items
  #

  def textual_namespace
    {:label => "Namespace", :value => @record.namespace}
  end

  def textual_port
    {:label => "Port", :value => @record.port}
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
