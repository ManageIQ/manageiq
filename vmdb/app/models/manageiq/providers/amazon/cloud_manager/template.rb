class ManageIQ::Providers::Amazon::CloudManager::Template < ManageIQ::Providers::CloudManager::Template

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.images[self.ems_ref]
  end

  def proxies4job(job=nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Image'
    }
  end

end
