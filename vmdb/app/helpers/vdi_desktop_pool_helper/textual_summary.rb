module VdiDesktopPoolHelper::TextualSummary

  #
  # Groups
  #

  def textual_group_properties
    items = %w{description vendor enabled assignment_behavior updated_on}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{vdi_farm ext_management_systems vdi_users vdi_desktops unassigned_vdi_desktops vdi_sessions}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def textual_description
    {:label => "Description", :value => @record.description}
  end

  def textual_vendor
    {:label => "Vendor", :value => @record.vendor}
  end

  def textual_enabled
    {:label => "Enabled", :value => @record.enabled}
  end

  def textual_assignment_behavior
    {:label => "Assignment Behavior", :value => @record.assignment_behavior}
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

  #def textual_ext_management_system
  #  ems = @record.ext_management_system
  #  label = ui_lookup(:table => "ext_management_system")
  #  h = {:label => label, :image => "ext_management_system", :value =>ems.blank? ? "None" : ems.name}
  #  if !ems.blank? && role_allows(:feature => "ext_management_system_show")
  #    h[:title] = "Show #{label} '#{ems.name}'"
  #    h[:link]  = url_for(:controller => 'management_system', :action => 'show', :id => ems)
  #  end
  #  h
  #end

  def textual_ext_management_systems
    num = @record.ext_management_systems.count
    h = {:label => ui_lookup(:tables=>"ems_infras"), :image => "ext_management_system", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"ems_infras")}"
      h[:link]  = url_for(:controller => 'vdi_desktop_pool', :action =>"show", :display=> 'ext_management_system', :id => @record)
    end
    h
  end

  def textual_vdi_users
    num = @record.vdi_users.count
    h = {:label => ui_lookup(:tables=>"vdi_user"), :image => "vdi_user", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_user")}"
      h[:link]  = url_for(:controller => 'vdi_desktop_pool', :action =>"show", :display=> 'vdi_user', :id => @record)
    end
    h
  end

  def textual_vdi_desktops
    num = @record.vdi_desktops.count
    h = {:label => "All #{ui_lookup(:tables=>"vdi_desktop")}", :image => "vdi_desktop", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_desktop")}"
      h[:link]  = url_for(:controller => 'vdi_desktop_pool', :action =>"show", :display=> 'vdi_desktop', :id => @record)
    end
    h
  end

  def textual_unassigned_vdi_desktops
    num = @record.unassigned_vdi_desktops.count
    h = {:label => "Unassigned #{ui_lookup(:tables=>"vdi_desktop")}", :image => "vdi_desktop", :value => num}
    if num > 0
      h[:title] = "Show all Unassigned #{ui_lookup(:tables=>"vdi_desktop")}"
      h[:link]  = url_for(:controller => 'vdi_desktop_pool', :action =>"show", :display=> 'unassigned_vdi_desktop', :id => @record)
    end
    h
  end

  def textual_vdi_sessions
    num = @record.vdi_sessions.count
    h = {:label => ui_lookup(:tables=>"vdi_session"), :image => "vdi_session", :value => num}
    if num > 0
      h[:title] = "Show all #{ui_lookup(:tables=>"vdi_session")}"
      h[:link]  = url_for(:controller => 'vdi_desktop_pool', :action =>"vdi_sessions",
                          :id => @record, :db => "vdi_desktop_pool")
    end
    h
  end

end
