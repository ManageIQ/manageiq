module MiqProxyHelper::GraphicalSummary
  # TODO: Verify why there are onclick events with miqCheckForChanges(), but only on some links.

  #
  # Groups
  #

  def graphical_group_properties
    items = %w{version heartbeat}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  def graphical_group_relationships
    items = %w{host ems storages vms miq_templates}
    items.collect { |m| self.send("graphical_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def graphical_version
    h = {:label => "Version"}
    h[:image] = "miqproxy"
    if @record.version.blank?
      h[:value] = "N/A"
    else
      h[:value] = @record.version
    end
    h
  end

  def graphical_heartbeat
    h = {:label => "Last Heartbeat"}
    h[:image] = "last-heartbeat"
    if @record.last_heartbeat.blank?
      h[:value] = "None"
    else
      h[:value] = "#{time_ago_in_words(@record.last_heartbeat.to_time).titleize} Ago"
    end
    h
  end

  def graphical_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_infra")
    h = {:label => label, :image => ems.emstype, :value => ems.name.truncate(13)}
    if role_allows(:feature => "ems_infra_show")
      h[:link] = link_to("", {:controller => 'ems_infra', :action => 'show', :id => ems}, :title => "Show parent #{label} '#{ems.name}'")
    end
    h
  end

  def graphical_host
    host = @record.host
    h = {:label => "Installed on Host", :image => "host", :value => (host.nil? ? "None" : host.name.truncate(13))}
    if host && role_allows(:feature => "host_show")
      h[:link] = link_to("", {:controller => 'host', :action => 'show', :id => host}, :title => "Show Host this SmartProxy is installed on")
    end
    h
  end

  def graphical_storages
    label = ui_lookup(:tables=>"storages")
    num   = @record.number_of(:storages)
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'storages'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_vms
    label = "VMs"
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'vms'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end

  def graphical_miq_templates
    label = ui_lookup(:tables=>"miq_template")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link] = link_to("", {:action => 'show', :id => @record, :display => 'miq_templates'}, :title => "Show all #{label}", :onclick=>"return miqCheckForChanges()")
    end
    h
  end
end
