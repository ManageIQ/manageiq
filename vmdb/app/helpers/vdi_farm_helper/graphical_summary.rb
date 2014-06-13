module VdiFarmHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{vdi_controllers vdi_desktop_pools vdi_desktops vdi_users vdi_sessions miq_proxies}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def graphical_vdi_controllers
    num = @record.vdi_controllers.count
    h = {:label => ui_lookup(:tables=>"vdi_controller"), :image => "vdi_controller", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_farm', :action =>'show', :display=>'vdi_controller', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_controller")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_desktop_pools
    num = @record.vdi_desktop_pools.count
    h = {:label => ui_lookup(:tables=>"vdi_desktop_pool"), :image => "vdi_desktop_pool", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_farm', :action =>'show', :display=>'vdi_desktop_pool', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_desktop_pool")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_users
    num = @record.vdi_users.count
    h = {:label => ui_lookup(:tables=>"vdi_user"), :image => "vdi_user", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_farm', :action =>'show', :display=>'vdi_user', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_user")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_desktops
    num = @record.vdi_desktops.count
    h = {:label => ui_lookup(:tables=>"vdi_desktop"), :image => "vdi_desktop", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_farm', :action =>'show', :display=>'vdi_desktop', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_desktop")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_farm', :action =>'vdi_sessions', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_session")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_miq_proxies
    num = @record.miq_proxies.count
    h = {:label => ui_lookup(:tables=>"miq_proxy"), :image => "miq_proxy", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_farm', :action=>"show", :display =>'miq_proxies', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"miq_proxy")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

end
