module CloudObjectStoreContainerHelper::TextualSummary
  def textual_group_properties
    %i(key size)
  end

  def textual_group_relationships
    %i(ems cloud_tenant cloud_object_store_objects)
  end

  def textual_group_tags
    %i(tags)
  end

  def textual_key
    @record.key
  end

  def textual_description
    @record.description
  end

  def textual_size
    {:label => _("Size"), :value => number_to_human_size(@record.bytes, :precision => 2)}
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenant")
    h = {:label => label, :image => "cloud_tenant", :value => (cloud_tenant.nil? ? "None" : cloud_tenant.name)}
    if cloud_tenant && role_allows(:feature => "cloud_tenant_show")
      h[:title] = _("Show this Cloud Object Store's parent %{parent}") % {:parent => label}
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end

  def textual_cloud_object_store_objects
    label = ui_lookup(:tables => "cloud_object_store_object")
    num = @record.number_of(:cloud_object_store_objects)
    h = {:label => label, :image => "cloud_object_store_object", :value => num}
    if num > 0 && role_allows(:feature => "cloud_object_store_object_show_list")
      h[:title] = _("Show this Cloud Object Store's child %{children}") % {:children => label}
      h[:link]  = url_for(:controller => 'cloud_object_store_object', :action => 'show_list')
    end
    h
  end
end
