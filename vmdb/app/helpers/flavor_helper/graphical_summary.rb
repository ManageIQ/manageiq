module FlavorHelper::GraphicalSummary

  #
  # Groups
  #


  def graphical_group_relationships
    items = %w{ems_cloud instances}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_ems_cloud
    ems = @record.ext_management_system
    label = ui_lookup(:table=>"ems_cloud")
    h = {:label => label, :image => (ems ? ems.emstype : "ems_cloud"), :value => (ems ? ems.name.truncate(13) : "None")}
    if ems && role_allows(:feature => "ems_cluster_show")
      h[:link] = link_to("", {:controller => 'ems_cloud', :action => 'show', :id => ems}, :title => "Show Cloud Provider '#{ems.name}'")
    end
    h
  end

  def graphical_instances
    label = ui_lookup(:tables=>"vm_cloud")
    num = @record.number_of(:vms)
    h = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @flavor, :display => 'instances'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end
end
