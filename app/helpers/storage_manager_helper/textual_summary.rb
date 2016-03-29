module StorageManagerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    %i(hostname ipaddress agent_type port zone_name last_update_status_str)
  end

  #
  # Items
  #

  def textual_hostname
    {:label => _("Hostname"), :value => @record.hostname}
  end

  def textual_ipaddress
    {:label => _("IP Address"), :value => @record.ipaddress}
  end

  def textual_agent_type
    {:label => _("Agent Type"), :value => @record.agent_type}
  end

  def textual_port
    {:label => _("Port"), :value => @record.port}
  end

  def textual_zone_name
    {:label => _("Zone"), :value => @record.zone_name}
  end

  def textual_last_update_status_str
    {:label => _("Last Update Status"), :value => @record.last_update_status_str}
  end
end
