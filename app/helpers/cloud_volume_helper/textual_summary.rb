module CloudVolumeHelper::TextualSummary
  include TextualMixins::TextualDescription
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName

  def textual_group_properties
    %i(name size bootable description)
  end

  def textual_group_relationships
    %i(ems availability_zone cloud_tenant base_snapshot cloud_volume_snapshots cloud_volume_backups attachments)
  end

  def textual_size
    {:label => _("Size"), :value => number_to_human_size(@record.size, :precision => 2)}
  end

  def textual_bootable
    @record.bootable.to_s
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_availability_zone
    availability_zone = @record.availability_zone
    label = ui_lookup(:table => "availability_zone")
    h = {
      :label => label,
      :image => "availability_zone",
      :value => (availability_zone.nil? ? _("None") : availability_zone.name)
    }
    if availability_zone && role_allows?(:feature => "availability_zone_show")
      h[:title] = _("Show this Volume's %{availability_zone}") % {:availability_zone => label}
      h[:link]  = url_for(:controller => 'availability_zone', :action => 'show', :id => availability_zone)
    end
    h
  end

  def textual_base_snapshot
    base_snapshot = @record.base_snapshot if @record.respond_to?(:base_snapshot)
    label = ui_lookup(:table => "base_snapshot")
    h = {
      :label => label,
      :image => "cloud_volume_snapshot",
      :value => (base_snapshot.nil? ? _("None") : base_snapshot.name)
    }
    if base_snapshot && role_allows?(:feature => "cloud_volume_snapshot_show")
      h[:title] = _("Show this Volume's %{parent}") % {:parent => label}
      h[:link]  = url_for(:controller => 'cloud_volume_snapshot', :action => 'show', :id => base_snapshot)
    end
    h
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenants")
    h = {:label => label, :image => "cloud_tenant", :value => (cloud_tenant.nil? ? _("None") : cloud_tenant.name)}
    if cloud_tenant && role_allows?(:feature => "cloud_tenant_show")
      h[:title] = _("Show this Volume's %{cloud_tenant}") % {:cloud_tenant => label}
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end

  def textual_cloud_volume_snapshots
    label = ui_lookup(:tables => "cloud_volume_snapshots")
    num   = @record.number_of(:cloud_volume_snapshots)
    h     = {:label => label, :image => "cloud_volume_snapshot", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_volume_snapshot_show_list")
      label = ui_lookup(:tables => "cloud_volume_snapshots")
      h[:title] = _("Show all %{models}") % {:models => label}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'cloud_volume_snapshots')
    end
    h
  end

  def textual_cloud_volume_backups
    label = ui_lookup(:tables => "cloud_volume_backups")
    num   = @record.number_of(:cloud_volume_backups)
    h     = {:label => label, :image => "cloud_volume_backup", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_volume_backup_show_list")
      label = ui_lookup(:tables => "cloud_volume_backups")
      h[:title] = _("Show all %{models}") % {:models => label}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'cloud_volume_backups')
    end
    h
  end

  def textual_attachments
    label = ui_lookup(:tables => "vm_cloud")
    num   = @record.number_of(:attachments)
    h     = {:label => label, :image => "vm", :value => num}
    if num > 0 && role_allows?(:feature => "vm_show_list")
      h[:title] = _("Show all attached %{models}") % {:models => label}
      h[:link]  = url_for(:action => 'show', :id => @volume, :display => 'instances')
    end
    h
  end
end
