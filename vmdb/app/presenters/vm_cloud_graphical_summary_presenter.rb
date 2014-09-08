class VmCloudGraphicalSummaryPresenter < GraphicalSummaryPresenter
  # TODO: Verify why there are onclick events with miqCheckForChanges(), but only on some links.

  #
  # Groups
  #
  def graphical_group_properties
    items = %w{container osinfo smart power_state compliance_status compliance_history}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_vm_cloud_relationships
    items = %w{ems availability_zone flavor drift scan_history}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_template_cloud_relationships
    items = %w{drift scan_history}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_configuration
    items = %w{guest_applications init_processes win32_services kernel_drivers filesystem_drivers filesystems registry_items advanced_settings}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end


  #
  # Items
  #
  def graphical_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_cloud")
    h = {:label => label, :image => ems.emstype, :value => ems.name.truncate(13)}
    if role_allows(:feature => "ems_infra_show")
      h[:link] = link_to("", {:controller => 'ems_infra', :action => 'show', :id => ems}, :title => "Show parent #{label} '#{ems.name}'")
    end
    h
  end

  def graphical_availability_zone
    availability_zone = @record.availability_zone
    label = ui_lookup(:table=>"availability_zone")
    return nil if availability_zone.nil?
    h = {:label => label, :image => "availability_zone", :value => availability_zone.name.truncate(13)}
    if role_allows(:feature => "availability_zone_show")
      h[:link] = link_to("", {:controller => 'availability_zone', :action => 'show', :id => availability_zone}, :title => "Show #{label} '#{availability_zone.name}'")
    end
    h
  end

  def graphical_flavor
    flavor = @record.flavor
    label = ui_lookup(:model => "flavor")
    h = {:label => label, :image => "flavor", :value => (flavor.nil? ? "None" : flavor.name.truncate(13))}
    if flavor && role_allows(:feature => "flavor_show")
      h[:link] = link_to("", {:controller => 'flavor', :action => 'show', :id => flavor}, :title => "Show #{label} '#{flavor.name}'")
    end
    h
  end
end