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

end
