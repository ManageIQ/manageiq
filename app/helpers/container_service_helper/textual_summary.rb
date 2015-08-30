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
      service_type
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
    @record.name
  end

  def textual_creation_timestamp
    format_timezone(@record.creation_timestamp)
  end

  def textual_resource_version
    @record.resource_version
  end

  def textual_session_affinity
    @record.session_affinity
  end

  def textual_service_type
    {:label => "Type", :value => @record.service_type}
  end

  def textual_portal_ip
    @record.portal_ip
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
