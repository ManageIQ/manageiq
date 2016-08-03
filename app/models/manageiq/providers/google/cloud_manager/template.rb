class ManageIQ::Providers::Google::CloudManager::Template < ManageIQ::Providers::CloudManager::Template
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.images[ems_ref]
  end
end
