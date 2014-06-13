module VdiDesktopHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w{agent_version connection_state power_state assigned_username updated_on}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{vdi_farm vdi_desktop_pool vdi_users vm_vdi vdi_sessions}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def textual_agent_version
    {:label => "Agent Version", :value => @record.agent_version}
  end

  def textual_connection_state
    {:label => "Connection", :value => @record.connection_state}
  end

  def textual_power_state
    {:label => "Power", :value => @record.power_state}
  end

  def textual_assigned_username
    {:label => "Assigned Username", :value => @record.assigned_username}
  end

  def textual_updated_on
    {:label => "Updated On", :value => @record.updated_at == nil ? "" : format_timezone(@record.updated_at)}
  end

  def textual_vdi_farm
    farm = @record.vdi_farm
    label = ui_lookup(:table => "vdi_farm")
    h = {:label => label, :image => "vdi_farm", :value =>farm.blank? ? "None" : farm.name}
    if !farm.blank? && role_allows(:feature => "vdi_farm_show")
      h[:title] = "Show #{label} '#{farm.name}'"
      h[:link]  = url_for(:controller => 'vdi_farm', :action => 'show', :id => farm)
    end
    h
  end

  def textual_vdi_desktop_pool
    dp = @record.vdi_desktop_pool
    label = ui_lookup(:table => "vdi_desktop_pool")
    h = {:label => label, :image => "vdi_desktop_pool", :value =>dp.blank? ? "None" : dp.name}
    if !dp.blank? && role_allows(:feature => "vdi_desktop_pool_show")
      h[:title] = "Show #{label} '#{dp.name}'"
      h[:link]  = url_for(:controller => 'vdi_desktop_pool', :action => 'show', :id => dp)
    end
    h
  end

  def textual_vdi_users
    num = @record.vdi_users.count
    h = {:label => ui_lookup(:tables=>"vdi_user"), :image => "vdi_user", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_user")}"
      h[:link]  = url_for(:controller => 'vdi_desktop', :action =>"show", :display=> 'vdi_user', :id => @record)
    end
    h
  end

  def textual_vm_vdi
    vm = @record.vm_vdi
    label = ui_lookup(:table => "vm")
    h = {:label => label, :image => "vm", :value =>vm.blank? ? "None" : vm.name}
    if !vm.blank? && role_allows(:feature => "vm_show")
      h[:title] = "Show #{label} '#{vm.name}'"
      h[:link]  = url_for(:controller => 'vm', :action => 'show', :id => vm)
    end
    h
  end

  def textual_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_session")}"
      h[:link]  = url_for(:controller => 'vdi_desktop', :action =>"vdi_sessions", :id => @record, :db => "vdi_desktop")
    end
    h
  end

end
