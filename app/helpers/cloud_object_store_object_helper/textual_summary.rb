module CloudObjectStoreObjectHelper::TextualSummary
  include TextualMixins::TextualGroupTags

  def textual_group_properties
    %i(key content_length last_modified etag)
  end

  def textual_group_relationships
    %i(parent_ems_cloud ems cloud_tenant cloud_object_store_container)
  end

  def textual_parent_ems_cloud
    textual_link(@record.ext_management_system.try(:parent_manager), :label => _("Parent Cloud Provider"))
  end

  def textual_ems
    textual_link(@record.ext_management_system)
  end

  def textual_key
    @record.key
  end

  def textual_content_length
    {:label => _("Content Length"), :value => number_to_human_size(@record.content_length, :precision => 2)}
  end

  def textual_last_modified
    @record.last_modified
  end

  def textual_etag
    @record.etag
  end

  def textual_cloud_tenant
    cloud_tenant = @record.cloud_tenant if @record.respond_to?(:cloud_tenant)
    label = ui_lookup(:table => "cloud_tenant")
    h = {:label => label, :icon => "pficon pficon-cloud-tenant", :value => (cloud_tenant.nil? ? "None" : cloud_tenant.name)}
    if cloud_tenant && role_allows?(:feature => "cloud_tenant_show")
      h[:title] = _("Show this Cloud Object's parent %{parent}") % {:parent => label}
      h[:link]  = url_for(:controller => 'cloud_tenant', :action => 'show', :id => cloud_tenant)
    end
    h
  end

  def textual_cloud_object_store_container
    object_store_container = @record.cloud_object_store_container if @record.respond_to?(:cloud_object_store_container)
    label = ui_lookup(:table => "cloud_object_store_container")
    h = {
      :label => label,
      :icon  => "product product-cloud_object_store",
      :value => (object_store_container.nil? ? "None" : object_store_container.key)
    }
    if object_store_container && role_allows?(:feature => "cloud_object_store_container_show")
      h[:title] = _("Show this Cloud Object's parent %{parent}") % {:parent => label}
      h[:link]  = url_for(:controller => 'cloud_object_store_container',
                          :action     => 'show',
                          :id         => object_store_container)
    end
    h
  end
end
