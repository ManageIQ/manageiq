module VdiDesktopPoolHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{vdi_farm ext_management_system vdi_users vdi_desktops unassigned_vdi_desktops vdi_sessions}
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

  def graphical_ext_management_system
    ems = @record.ext_management_system
    label = ui_lookup(:table => "ems_infra")
    h = {:label => label, :image => "ext_management_system", :value =>ems.blank? ? "None" : ems.name.truncate(13)}
    if !ems.blank? && role_allows(:feature => "ems_infra_show")
      h[:link] = link_to("", {:controller => 'ems_infra', :action => 'show', :id => ems}, :title => "Show #{label} '#{h(ems.name)}'", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_users
    num = @record.vdi_users.count
    h = {:label => ui_lookup(:tables=>"vdi_user"), :image => "vdi_user", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_desktop_pool', :action =>'show', :display=>'vdi_user', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_user")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_desktops
    num = @record.vdi_desktops.count
    h = {:label => "All #{ui_lookup(:tables=>"vdi_desktop")}", :image => "vdi_desktop", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_desktop_pool', :action =>'show', :display=>'vdi_desktop', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_desktop")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_unassigned_vdi_desktops
    num = @record.unassigned_vdi_desktops.count
    h = {:label => "Unassigned #{ui_lookup(:tables=>"vdi_desktop")}", :image => "vdi_desktop", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_desktop_pool', :action =>'show', :display=>'unassigned_vdi_desktop', :id => @record}, :title => "Show all Unassigned #{ui_lookup(:tables=>"vdi_desktop")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

end
