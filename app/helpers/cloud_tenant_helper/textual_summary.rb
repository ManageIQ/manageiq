module CloudTenantHelper::TextualSummary
  #
  # Groups
  #
  def textual_group_relationships
    %i(ems_cloud security_groups instances images)
  end

  def textual_group_tags
    %i(tags)
  end

  def textual_group_quotas
    quotas = @record.cloud_resource_quotas.order(:service_name, :name)
    quotas.collect { |quota| textual_quotas(quota) }
  end

  #
  # Items
  #
  def textual_ems_cloud
    textual_link(@record.ext_management_system)
  end

  def textual_security_groups
    @record.security_groups
  end

  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @cloud_tenant, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_images
    label = ui_lookup(:tables => "template_cloud")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows(:feature => "miq_template_show_list")
      h[:link]  = url_for(:action => 'show', :id => @cloud_tenant, :display => 'images')
      h[:title] = _("Show all %{label}") % {:label => label}
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
