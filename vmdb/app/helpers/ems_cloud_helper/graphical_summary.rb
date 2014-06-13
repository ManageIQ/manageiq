module EmsCloudHelper::GraphicalSummary

  #
  # Groups
  #

  def graphical_group_relationships
    items = %w{instances images availability_zones flavors}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_instances
    label = ui_lookup(:tables=>"vm_cloud")
    num = @ems.number_of(:vms)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'vms'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_images
    label = ui_lookup(:tables=>"template_cloud")
    num = @ems.number_of(:miq_templates)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'miq_templates'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_availability_zones
    label = ui_lookup(:tables=>"availability_zone")
    num = @ems.number_of(:availability_zones)
    h = {:label => label, :image => "availability_zone", :value => num}
    if num > 0 && role_allows(:feature => "availability_zone_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'availability_zones'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end
  def graphical_flavors
    label = ui_lookup(:tables=>"flavors")
    num = @ems.number_of(:flavors)
    h = {:label => label, :image => "flavor", :value => num}
    if num > 0 && role_allows(:feature => "flavor_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @ems, :display => 'flavors'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

end
