module CloudVolumeSnapshotHelper::TextualSummary

  def textual_group_properties
    %i(name size description)
  end

  def textual_group_relationships
    %i(ems cloud_volume based_volumes cloud_tenant)
  end

  def textual_group_tags
    %i(tags)
  end

  def textual_name
    @record.name
  end

  def textual_description
    @record.description
  end

  def textual_size
    {:label => "Size", :value => number_to_human_size(@record.size, :precision => 2)}
  end

  def textual_based_volumes
    label = ui_lookup(:table => "based_volumes")
    num   = @record.total_based_volumes
    h     = {:label => label, :image => "cloud_volume", :value => num}
    if num > 0 && role_allows(:feature => "cloud_volume_show_list")
      label = ui_lookup(:table => "cloud_volumes")
      h[:title] = "Show all #{label} based on this Snapshot."
      h[:link]  = url_for(:action => 'show', :id => @record, :display => 'cloud_volumes')
    end
    h
  end

  def textual_cloud_volume
    textual_link(@record.cloud_volume)
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenants")
    h = {:label => label, :image => "cloud_tenant", :value => (cloud_tenant.nil? ? "None" : cloud_tenant.name)}
    if cloud_tenant && role_allows(:feature => "cloud_tenant_show")
      h[:title] = "Show this Snapshot's #{label}"
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end
end
