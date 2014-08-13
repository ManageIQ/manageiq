class StorageTextualSummaryPresenter < TextualSummaryPresenter
  def textual_datastores
    label = ui_lookup(:tables=>"storages")
    num   = @record.storages_size
    h     = {:label => label, :image => "storage", :value => num}
    if num > 0 && role_allows(:feature => "storage_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'storages')
    end
    h
  end

  def textual_element_name
    {:label => "Element Name", :value => @record.element_name}
  end

  def textual_group_infrastructure_relationships
    items = %w{vms hosts datastores}
    call_items(items)
  end

  def textual_group_smart_management
    items = %w{tags}
    call_items(items)
  end

  def textual_hosts
    label = "Hosts"
    num   = @record.hosts_size
    h     = {:label => label, :image => "host", :value => num}
    if num > 0 && role_allows(:feature => "host_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'hosts')
    end
    h
  end

  def textual_name
    {:label => "Name", :value => @record.evm_display_name}
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

  def textual_vms
    label = "VMs"
    num   = @record.vms_size
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'vms')
    end
    h
  end

  def textual_zone_name
    {:label => "Zone Name", :value => @record.zone_name}
  end

end