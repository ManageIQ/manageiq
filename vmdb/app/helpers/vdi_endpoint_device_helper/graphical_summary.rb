module VdiEndpointDeviceHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{vdi_sessions}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def graphical_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_endpoint_device', :action =>'vdi_sessions', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_session")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

end
