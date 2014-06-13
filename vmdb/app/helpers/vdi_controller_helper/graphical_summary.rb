module VdiControllerHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{vdi_farm vdi_sessions}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def graphical_vdi_farm
    farm = @record.vdi_farm
    return nil if farm.nil?
    label = ui_lookup(:table => "vdi_farm")
    h = {:label => label, :image => "vdi_farm", :value => farm.name.truncate(13)}
    if role_allows(:feature => "vdi_farm_show")
      h[:link] = link_to("", {:controller => 'vdi_farm', :action => 'show', :id => farm}, :title => "Show #{label} '#{h(farm.name)}'", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_controller', :action => 'vdi_sessions', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_session")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

end
