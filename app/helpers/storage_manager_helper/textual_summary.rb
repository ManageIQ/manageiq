module StorageManagerHelper::TextualSummary
  #
  # Groups
  #

  def textual_group_properties
    items = %w{hostname ipaddress agent_type port zone_name last_update_status_str}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_hostname
    {:label => "Hostname", :value => @record.hostname}
  end

  def textual_ipaddress
    {:label => "IPAdress", :value => @record.ipaddress}
  end

  def textual_agent_type
    {:label => "Agent Type", :value => @record.agent_type}
  end

  def textual_port
    {:label => "Port", :value => @record.port}
  end

  def textual_zone_name
    {:label => "Zone", :value => @record.zone_name}
  end

  def textual_last_update_status_str
    {:label => "Last Update Status", :value => @record.last_update_status_str}
  end
end
