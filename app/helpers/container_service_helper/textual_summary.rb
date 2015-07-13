module ContainerServiceHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(
      name
      creation_timestamp
      resource_version
      session_affinity
      portal_ip)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  def textual_group_port_configs
    labels = [_("Name"), _("Port"), _("Target Port"), _("Protocol")]
    h = {:labels => labels}
    h[:values] = @record.container_service_port_configs.collect do |config|
      [
        config.name || _("<Unnamed>"),
        config.port,
        config.target_port,
        config.protocol
      ]
    end
    h
  end

  def textual_group_relationships
    items = %w(ems container_project container_groups)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end
  #
  # Items
  #

  def textual_namespace
    {:label => "Namespace", :value => @record.namespace.to_s}
  end

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_creation_timestamp
    {:label => "Creation Timestamp", :value => format_timezone(@record.creation_timestamp)}
  end

  def textual_resource_version
    {:label => "Resource Version", :value => @record.resource_version}
  end

  def textual_session_affinity
    {:label => "Session Affinity", :value => @record.session_affinity}
  end

  def textual_portal_ip
    {:label => "Portal IP", :value => @record.portal_ip}
  end

  def textual_port_config(port_conf)
    name = port_conf.name

    name = _("<Unnamed>") if name.blank?

    {
      :label => name,
      :value => "#{port_conf.protocol} port #{port_conf.port} to pods on target port:'#{port_conf.target_port}'"
    }
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

  def textual_container_groups
    num_of_container_groups = @record.number_of(:container_groups)
    label = ui_lookup(:tables => "container_groups")
    h = {:label => label, :image => "container_group", :value => num_of_container_groups}
    if  num_of_container_groups > 0 && role_allows(:feature => "container_group_show")
      h[:link] = url_for(:action => 'show', :controller => 'container_service', :display => 'container_groups')
    end
    h
  end

  def textual_container_project
    project = @record.container_project
    return nil if project.nil?
    label = ui_lookup(:table => "container_project")
    h = {:label => label, :image => "container_project", :value => project.name}
    if role_allows(:feature => "container_project_show")
      h[:title] = "Show parent #{label} '#{project.name}'"
      h[:link] = url_for(:controller => 'container_project', :action => 'show', :id => project)
    end
    h
  end
end
