module VdiUserHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w{updated_on}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{vdi_desktop_pools vdi_desktops vdi_sessions}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def textual_updated_on
    {:label => "Updated On", :value => @record.updated_at == nil ? "" : format_timezone(@record.updated_at)}
  end

  def textual_vdi_desktop_pools
    num = @record.vdi_desktop_pools.count
    h = {:label => ui_lookup(:tables=>"vdi_desktop_pool"), :image => "vdi_desktop_pool", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_desktop_pool")}"
      h[:link]  = url_for(:controller => 'vdi_user', :action =>"show", :display=> 'vdi_desktop_pool', :id => @record)
    end
    h
  end

  def textual_vdi_desktops
    num = @record.vdi_desktops.count
    h = {:label => ui_lookup(:tables=>"vdi_desktop"), :image => "vdi_desktop", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_desktop")}"
      h[:link]  = url_for(:controller => 'vdi_user', :action =>"show", :display=> 'vdi_desktop', :id => @record)
    end
    h
  end

  def textual_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_session")}"
      h[:link]  = url_for(:controller => 'vdi_user', :action =>"vdi_sessions", :id => @record)
    end
    h
  end

end
