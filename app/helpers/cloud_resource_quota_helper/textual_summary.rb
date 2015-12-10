module CloudResourceQuotaHelper::TextualSummary
  #
  # Groups
  #
  def textual_group_properties
    %i(service_name name value type)
  end

  def textual_group_relationships
    %i(ems_cloud cloud_tenant)
  end

  def textual_group_tags
    %i(tags)
  end

  def textual_service_name
    @record.service_name
  end

  def textual_name
    @record.name
  end

  def textual_value
    @record.value
  end

  def textual_type
    @record.type
  end

  #
  # Items
  #
  def textual_ems_cloud
    textual_link(@record.ext_management_system)
  end

  def textual_cloud_tenant
    textual_link(@record.cloud_tenant)
  end
end
