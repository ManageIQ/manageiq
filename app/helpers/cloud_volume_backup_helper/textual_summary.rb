module CloudVolumeBackupHelper::TextualSummary
  include TextualMixins::TextualDescription
  include TextualMixins::TextualGroupTags
  include TextualMixins::TextualName

  def textual_group_properties
    %i(name status size)
  end

  def textual_group_relationships
    %i(ems cloud_volume cloud_tenant)
  end

  def textual_status
    {:label => _("Status"), :value => @record.status}
  end

  def textual_size
    {:label => _("Size"), :value => number_to_human_size(@record.size, :precision => 2)}
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
    h = {:label => label, :image => "cloud_tenant", :value => (cloud_tenant.nil? ? _("None") : cloud_tenant.name)}
    if cloud_tenant && role_allows?(:feature => "cloud_tenant_show")
      h[:title] = _("Show this Backup's %{parent}") % {:parent => label}
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end
end
