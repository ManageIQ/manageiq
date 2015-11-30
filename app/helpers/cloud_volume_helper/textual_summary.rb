module CloudVolumeHelper::TextualSummary

  def textual_group_properties
    %i(name size bootable description)
  end

  def textual_group_relationships
    %i(ems availability_zone cloud_tenant)
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

  def textual_bootable
    @record.bootable.to_s
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_availability_zone
    availability_zone = @record.availability_zone
    label = ui_lookup(:table => "availability_zone")
    h = {:label => label, :image => "availability_zone", :value => (availability_zone.nil? ? "None" : availability_zone.name)}
    if availability_zone && role_allows(:feature => "availability_zone_show")
      h[:title] = "Show this Volume's #{label}"
      h[:link]  = url_for(:controller => 'availability_zone', :action => 'show', :id => availability_zone)
    end
    h
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenants")
    h = {:label => label, :image => "cloud_tenant", :value => (cloud_tenant.nil? ? "None" : cloud_tenant.name)}
    if cloud_tenant && role_allows(:feature => "cloud_tenant_show")
      h[:title] = "Show this Volume's #{label}"
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end
end
