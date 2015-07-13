module CloudTenantHelper::TextualSummary
  #
  # Groups
  #
  def textual_group_relationships
    items = %w{ems_cloud security_groups instances images}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_tags
    items = %w{tags}
    items.collect { |m| self.send("textual_#{m}") }.flatten.compact
  end

  def textual_group_quotas
    quotas = @record.cloud_resource_quotas.order(:service_name, :name)
    quotas.collect { |quota| textual_quotas(quota) }.flatten.compact
  end

  #
  # Items
  #
  def textual_ems_cloud
    ems = @record.ext_management_system
    return nil if ems.nil?
    label = ui_lookup(:table => "ems_cloud")
    h = {:label => label, :image => "vendor-#{ems.image_name}", :value => ems.name}
    if role_allows(:feature => "ems_cloud_show")
      h[:title] = "Show this Cloud Tenant's #{label} '#{ems.name}'"
      h[:link]  = url_for(:controller => 'ems_cloud', :action => 'show', :id => ems)
    end
    h
  end

  def textual_security_groups
    label = ui_lookup(:tables => "security_groups")
    num   = @record.number_of(:security_groups)
    h     = {:label => label, :image => "security_group", :value => num}
    if num > 0
      h[:title] = "Show all #{label}"
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'security_groups')
    end
    h
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @cloud_tenant, :display => 'instances')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_images
    label = ui_lookup(:tables => "template_cloud")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link]  = url_for(:action => 'show', :id => @cloud_tenant, :display => 'images')
      h[:title] = "Show all #{label}"
    end
    h
  end

  def textual_tags
    label = "#{session[:customer_name]} Tags"
    h = {:label => label}
    tags = session[:assigned_filters]
    if tags.blank?
      h[:image] = "smarttag"
      h[:value] = "No #{label} have been assigned"
    else
      h[:value] = tags.sort_by { |category, assigned| category.downcase }.collect { |category, assigned| {:image => "smarttag", :label => category, :value => assigned} }
    end
    h
  end

  def textual_quotas(quota)
    label = quota_label(quota.service_name, quota.name)
    num   = quota.value.to_i
    used = quota.used.to_i < 0 ? "Unknown" : quota.used
    value = num < 0 ? "Unlimited" : "#{used} used of #{quota.value}"
    {:label => label, :value => value}
  end

  def quota_label(service_name, quota_name)
    "#{service_name.titleize} - #{quota_name.titleize}"
  end
end
