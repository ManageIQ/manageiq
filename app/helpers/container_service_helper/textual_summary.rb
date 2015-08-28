module ContainerServiceHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(
      name
      creation_timestamp
      resource_version
      session_affinity
      portal_ip
    )
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
    %i(ems container_project container_routes container_groups container_nodes)
  end

  def textual_group_smart_management
    items = %w(tags)
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
end
