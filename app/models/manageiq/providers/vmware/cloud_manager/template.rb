class ManageIQ::Providers::Vmware::CloudManager::Template < ManageIQ::Providers::CloudManager::Template
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.catalog_items.get_single_catalog_item(ems_ref)
  end

  def validate_smartstate_analysis
    validate_unsupported("Smartstate Analysis")
  end
end
