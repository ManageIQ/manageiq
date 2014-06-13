module VdiControllerHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w{version zone_preference updated_on}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{vdi_farm vdi_sessions}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_vdi_farm
    farm = @record.vdi_farm
    return nil if farm.nil?
    label = ui_lookup(:table => "vdi_farm")
    h = {:label => label, :image => "vdi_farm", :value => farm.name}
    if role_allows(:feature => "vdi_farm_show")
      h[:title] = "Show #{label} '#{farm.name}'"
      h[:link]  = url_for(:controller => 'vdi_farm', :action => 'show', :id => farm)
    end
    h
  end

  def textual_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_session")}"
      h[:link]  = url_for(:controller => 'vdi_controller', :action => 'vdi_sessions', :id => @record)
    end
    h
  end

  def textual_version
    {:label => "Version", :value => @record.version}
  end

  def textual_zone_preference
    {:label => "Zone Preference", :value => @record.zone_preference}
  end

  def textual_updated_on
    {:label => "Updated On", :value => @record.updated_at == nil ? "" : format_timezone(@record.updated_at)}
  end

end
