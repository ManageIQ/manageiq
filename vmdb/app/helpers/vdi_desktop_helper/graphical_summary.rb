module VdiDesktopHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{vdi_farm vdi_desktop_pool vdi_user vm_vdi vdi_sessions}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def graphical_vdi_farm
    farm = @record.vdi_farm
    label = ui_lookup(:table => "vdi_farm")
    h = {:label => label, :image => "vdi_farm", :value =>farm.blank? ? "None" : farm.name.truncate(13)}
    if !farm.blank? && role_allows(:feature => "vdi_farm_show")
      h[:link] = link_to("", {:controller => 'vdi_farm', :action => 'show', :id => farm}, :title => "Show #{label} '#{h(farm.name)}'", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_desktop_pool
    dp = @record.vdi_desktop_pool
    label = ui_lookup(:table => "vdi_desktop_pool")
    h = {:label => label, :image => "vdi_desktop_pool", :value =>dp.blank? ? "None" : dp.name.truncate(13)}
    if !dp.blank? && role_allows(:feature => "vdi_desktop_pool_show")
      h[:link] = link_to("", {:controller => 'vdi_desktop_pool', :action => 'show', :id => dp}, :title => "Show #{label} '#{h(dp.name)}'", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_user
    user = @record.vdi_user
    label = ui_lookup(:table => "vdi_user")
    h = {:label => label, :image => "vdi_user", :value =>user.blank? ? "None" : user.name.truncate(13)}
    if !user.blank? && role_allows(:feature => "vdi_user_show")
      h[:link] = link_to("", {:controller => 'vdi_user', :action => 'show', :id => user}, :title => "Show #{label} '#{h(user.name)}'", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vm_vdi
    vm = @record.vm_vdi
    label = ui_lookup(:table => "vm")
    h = {:label => label, :image => "vm", :value =>vm.blank? ? "None" : vm.name.truncate(13)}
    if !vm.blank? && role_allows(:feature => "vm_vdi_show")
      h[:link] = link_to("", {:controller => 'vm_vdi', :action => 'show', :id => vm}, :title => "Show #{label} '#{h(vm.name)}'", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_desktop', :action =>'vdi_sessions',
                                :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_session")}",
                                :onclick => "return miqCheckForChanges()", :db => "vdi_desktop")
    end
    h
  end

end
