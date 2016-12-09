module CloudVolumeSnapshotHelper::TextualSummary
  include TextualMixins::TextualDescription
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName

  def textual_group_properties
    %i(name size description)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems cloud_volume based_volumes cloud_tenant)
  end

  def textual_size
    {:label => _("Size"), :value => number_to_human_size(@record.size, :precision => 2)}
  end

  def textual_based_volumes
    label = ui_lookup(:table => "based_volumes")
    num   = @record.total_based_volumes
    h     = {:label => label, :image => "100/cloud_volume.png", :value => num}
    if num > 0 && role_allows?(:feature => "cloud_volume_show_list")
      label = ui_lookup(:table => "cloud_volumes")
      h[:title] = _("Show all %{volumes} based on this Snapshot.") % {:volumes => label}
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'based_volumes')
    end
    h
  end

  def textual_cloud_volume
    textual_link(@record.cloud_volume)
  end

  def textual_parent_ems_cloud
    textual_link(@record.ext_management_system.try(:parent_manager), :label => _("Parent Cloud Provider"))
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenants")
    h = {:label => label, :image => "100/cloud_tenant.png", :value => (cloud_tenant.nil? ? _("None") : cloud_tenant.name)}
    if cloud_tenant && role_allows?(:feature => "cloud_tenant_show")
      h[:title] = _("Show this Snapshot's %{parent}") % {:parent => label}
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end
end
