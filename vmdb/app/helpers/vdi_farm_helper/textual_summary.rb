module VdiFarmHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w{vendor edition license_server_name zone updated_on}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{vdi_controllers vdi_desktop_pools vdi_desktops vdi_users vdi_sessions miq_proxies}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def textual_vendor
    {:label => "Vendor", :value => @record.vendor}
  end

  def textual_edition
    {:label => "Edition", :value => @record.edition}
  end

  def textual_license_server_name
    {:label => "License Server Name", :value => @record.license_server_name}
  end

  def textual_zone
    {:label => "Zone", :value => @record.zone.nil? ? "default" :@record.zone.name }
  end

  def textual_updated_on
    {:label => "Updated On", :value => @record.updated_at == nil ? "" : format_timezone(@record.updated_at)}
  end

  def textual_vdi_controllers
    num = @record.vdi_controllers.count
    h = {:label => ui_lookup(:tables=>"vdi_controller"), :image => "vdi_controller", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_controller")}"
      h[:link]  = url_for(:controller => 'vdi_farm', :action =>"show", :display=> 'vdi_controller', :id => @record)
    end
    h
  end

  def textual_vdi_desktop_pools
    num = @record.vdi_desktop_pools.count
    h = {:label => ui_lookup(:tables=>"vdi_desktop_pool"), :image => "vdi_desktop_pool", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_desktop_pool")}"
      h[:link]  = url_for(:controller => 'vdi_farm', :action =>"show", :display=> 'vdi_desktop_pool', :id => @record)
    end
    h
  end

  def textual_vdi_desktops
    num = @record.vdi_desktops.count
    h = {:label => ui_lookup(:tables=>"vdi_desktop"), :image => "vdi_desktop", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_desktop")}"
      h[:link]  = url_for(:controller => 'vdi_farm', :action =>"show", :display=> 'vdi_desktop', :id => @record)
    end
    h
  end

  def textual_vdi_users
    num = @record.vdi_users.count
    h = {:label => ui_lookup(:tables=>"vdi_user"), :image => "vdi_user", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_user")}"
      h[:link]  = url_for(:controller => 'vdi_farm', :action =>"show", :display=> 'vdi_user', :id => @record)
    end
    h
  end

  def textual_miq_proxies
    num = @record.miq_proxies.count
    h = {:label => ui_lookup(:tables=>"miq_proxy"), :image => "miq_proxy", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"miq_proxy")}"
      h[:link]  = url_for(:controller => 'vdi_farm', :action =>"show", :display=> 'miq_proxies', :id => @record)
    end
    h
  end

  def textual_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_session")}"
      h[:link]  = url_for(:controller => 'vdi_farm', :action =>"vdi_sessions", :id => @record)
    end
    h
  end

end
