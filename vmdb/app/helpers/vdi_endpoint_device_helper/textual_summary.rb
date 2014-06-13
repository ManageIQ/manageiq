module VdiEndpointDeviceHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w{ipaddress updated_on}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{vdi_sessions}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def textual_ipaddress
    {:label => "IPAddress", :value => @record.ipaddress}
  end

  def textual_updated_on
    {:label => "Updated On", :value => @record.updated_at == nil ? "" : format_timezone(@record.updated_at)}
  end

  def textual_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_session")}"
      h[:link]  = url_for(:controller => 'vdi_endpoint_device', :action =>"vdi_sessions", :id => @record)
    end
    h
  end

end
