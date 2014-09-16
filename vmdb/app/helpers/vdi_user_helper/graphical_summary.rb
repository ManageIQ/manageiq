module VdiUserHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{vdi_desktop_pools vdi_desktops vdi_sessions}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #
  def graphical_vdi_desktop_pools
    num = @record.vdi_desktop_pools.count
    h = {:label => ui_lookup(:tables=>"vdi_desktop_pool"), :image => "vdi_desktop_pool", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_user', :action =>'show', :display=>'vdi_desktop_pool', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_desktop_pool")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

  def graphical_vdi_desktops
    num = @record.vdi_desktops.count
    h = {:label => ui_lookup(:tables=>"vdi_desktop"), :image => "vdi_desktop", :value => num}
    if num > 0
      h[:link]  = link_to("", {:controller => 'vdi_user', :action =>'show', :display=>'vdi_desktop', :id => @record}, :title => "Show all #{ui_lookup(:tables=>"vdi_desktop")}", :onclick => "return miqCheckForChanges()")
    end
    h
  end

end
