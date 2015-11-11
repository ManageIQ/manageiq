class ManageIQ::Providers::Azure::CloudManager::Template < ::ManageIQ::Providers::CloudManager::Template

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.images[self.ems_ref]
  end
end
