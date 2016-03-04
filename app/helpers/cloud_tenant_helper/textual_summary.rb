module CloudTenantHelper::TextualSummary
  #
  # Groups
  #
  def textual_group_relationships
    %i(ems_cloud security_groups instances images cloud_volumes cloud_volume_snapshots)
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

  def textual_cloud_volumes
    label = ui_lookup(:tables => "cloud_volumes")
    num   = @record.number_of(:cloud_volumes)
    h     = {:label => label, :image => "cloud_volume", :value => num}
    if num > 0 && role_allows(:feature => "cloud_volume_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'show', :id => @cloud_tenant, :display => "cloud_volumes")
    end
    h
  end

  def textual_cloud_volume_snapshots
    label = ui_lookup(:tables => "cloud_volume_snapshots")
    num   = @record.number_of(:cloud_volume_snapshots)
    h     = {:label => label, :image => "cloud_volume_snapshot", :value => num}
    if num > 0 && role_allows(:feature => "cloud_volume_snapshot_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'show', :id => @cloud_tenant, :display => "cloud_volume_snapshots")
    end
    h
  end
end
