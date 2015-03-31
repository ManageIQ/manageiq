module ContainerServiceHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w(namespace name port creation_timestamp resource_version session_affinity portal_ip protocol container_port)
    items.collect { |m| send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_namespace
    {:label => "Namespace", :value => @record.namespace}
  end

  def textual_name
    {:label => "Name", :value => @record.name}
  end

  def textual_port
    {:label => "Port", :value => @record.port}
  end

  def textual_creation_timestamp
    {:label => "Creation Timestamp", :value => @record.creation_timestamp}
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

  def textual_protocol
    {:label => "Protocol", :value => @record.protocol}
  end

  def textual_container_port
    {:label => "Container Port", :value => @record.container_port}
  end
end
