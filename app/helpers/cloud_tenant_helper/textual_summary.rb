module CloudTenantHelper::TextualSummary
  include TextualMixins::TextualEmsCloud
  include TextualMixins::TextualGroupTags
  #
  # Groups
  #
  def textual_group_relationships
    %i(ems_cloud instances images cloud_object_store_containers cloud_volumes cloud_volume_snapshots
       cloud_networks cloud_subnets network_routers security_groups floating_ips network_ports)
  end

  def textual_group_quotas
    quotas = @record.cloud_resource_quotas.order(:service_name, :name)
    quotas.collect { |quota| textual_quotas(quota) }
  end

  #
  # Items
  #
  def textual_instances
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:vms)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'instances')
      h[:title] = _("Show all %{label}") % {:label => label}
    end
    h
  end

  def textual_images
    label = ui_lookup(:tables => "template_cloud")
    num   = @record.number_of(:miq_templates)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows?(:feature => "miq_template_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'images')
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
    label = _('Volumes')
    num   = @record.number_of(:cloud_volumes)
    h     = {:label => label, :image => "cloud_volume", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_volume_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => "cloud_volumes")
    end
    h
  end

  def textual_cloud_volume_snapshots
    label = _('Volume Snapshots')
    num   = @record.number_of(:cloud_volume_snapshots)
    h     = {:label => label, :image => "cloud_volume_snapshot", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_volume_snapshot_show_list")
      h[:title] = _("Show all %{label}") % {:label => label}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => "cloud_volume_snapshots")
    end
    h
  end

  def textual_cloud_object_store_containers
    label = ui_lookup(:tables => "cloud_object_store_container")
    num   = @record.number_of(:cloud_object_store_containers)
    h     = {:label => label, :image => "cloud_object_store_container", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_object_store_container_show_list")
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'cloud_object_store_containers')
      h[:title] = _("Show all %{models}") % {:models => label}
    end
    h
  end

  def textual_security_groups
    @record.security_groups
  end

  def textual_floating_ips
    @record.floating_ips
  end

  def textual_network_routers
    @record.network_routers
  end

  def textual_network_ports
    @record.network_ports
  end

  def textual_cloud_networks
    @record.cloud_networks
  end
  def textual_cloud_subnets
    @record.cloud_subnets
  end
end
