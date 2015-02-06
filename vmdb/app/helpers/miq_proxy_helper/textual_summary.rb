module MiqProxyHelper::TextualSummary
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #

  def textual_group_properties
    items = %w{version heartbeat ws_port architecture}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_relationships
    items = %w{host ems storages vms miq_templates}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_smart_management
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  #
  # Items
  #

  def textual_version
    {:label => "Version", :value => "#{@record.version.blank? ? 'N/A' : @record.version}", :image => "miqproxy"}
  end

  def textual_heartbeat
    {:label => "Last Heartbeat", :value => "#{@record.last_heartbeat.blank? ? 'None' : time_ago_in_words(@record.last_heartbeat.to_time).titleize}", :image => "last-heartbeat"}
  end

  def textual_ws_port
    {:label => "WS Port", :value => "#{@record.ws_port}"}
  end

  def textual_architecture
    {:label => "Architecture", :value => @record.arch}
  end

  def textual_host
    host = @record.host
    h = {:label => "Installed on Host", :image => "ems_cluster", :value => (host.nil? ? "None" : host.name)}
    if host && role_allows(:feature => "host_show")
      h[:title] = "Show Host this SmartProxy is installed on"
      h[:link]  = url_for(:controller => 'host', :action => 'show', :id => host)
    end
    h
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_infra")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_infra_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_infra', :action => 'show', :id => ems)
    end
    h
  end

  def textual_storages
    label = ui_lookup(:tables=>"storages")
    num   = @record.number_of(:storages)
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'storages')
    end
    h
  end

  def textual_vms
    label = "VMs"
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_miq_templates
    label = ui_lookup(:tables=>"miq_template")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'miq_templates')
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h     = {:label => label}
    tags  = session[:assigned_filters]
    if tags.empty?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned } }
    end
    h
  end
end
