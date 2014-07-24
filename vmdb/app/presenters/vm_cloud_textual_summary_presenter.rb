class VmCloudTextualSummaryPresenter < TextualSummaryPresenter
  # TODO: Determine if DoNav + url_for + :title is the right way to do links, or should it be link_to with :title

  #
  # Groups
  #
  def textual_group_properties
    items = %w{name region server description ipaddress custom_1 container tools_status osinfo architecture advanced_settings resources guid}
    call_items(items)
  end

  def textual_group_vm_cloud_relationships
    items = %w(ems availability_zone flavor drift scan_history security_groups cloud_network cloud_subnet)
    call_items(items)
  end

  def textual_group_template_cloud_relationships
    items = %w{ems drift scan_history}
    call_items(items)
  end

  def textual_group_security
    items = %w{users groups patches key_pairs}
    call_items(items)
  end


  #
  # Items
  #
  def textual_architecture
    return nil if @record.kind_of?(VmOpenstack) || @record.kind_of?(TemplateOpenstack)
    bitness = @record.hardware.try(:bitness)
    {:label => "Architecture ", :value => bitness.nil? ? "" : "#{bitness} bit"}
  end

  def textual_ems
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_cloud")
    h = {:label => label, :image => "vendor-#{ems.emstype.downcase}", :value => ems.name}
    if role_allows(:feature => "ems_cloud_show")
      h[:title] = "Show parent #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_cloud', :action => 'show', :id => ems)
    end
    h
  end

  def textual_availability_zone
    availability_zone = @record.availability_zone
    label = ui_lookup(:table => "availability_zone")
    h = {:label => label, :image => "availability_zone", :value => (availability_zone.nil? ? "None" : availability_zone.name)}
    if availability_zone && role_allows(:feature => "availability_zone_show")
      h[:title] = "Show this VM's #{label}"
      h[:link]  = url_for(:controller => 'availability_zone', :action => 'show', :id => availability_zone)
    end
    h
  end

  def textual_flavor
    flavor = @record.flavor
    label = ui_lookup(:table => "flavor")
    h = {:label => label, :image => "flavor", :value => (flavor.nil? ? "None" : flavor.name)}
    if flavor && role_allows(:feature => "flavor_show")
      h[:title] = "Show this VM's #{label}"
      h[:link]  = url_for(:controller => 'flavor', :action => 'show', :id => flavor)
    end
    h
  end

  def textual_key_pairs
    return nil if @record.kind_of?(TemplateCloud)
    h = {:label => "Key Pairs"}
    key_pairs = @record.key_pairs
    h[:value] = key_pairs.blank? ? "N/A" : key_pairs.collect(&:name).join(", ")
    h
  end

  def textual_security_groups
    label = ui_lookup(:tables => "security_group")
    num   = @record.number_of(:security_groups)
    h     = {:label => label, :image => "security_group", :value => num}
    if num > 0 && role_allows(:feature => "security_group_show_list")
      h[:title] = "Show all #{label}"
      h[:explorer] = true
      h[:link]  = url_for(:action => 'security_groups', :id => @record, :display => "security_groups")
    end
    h
  end
end