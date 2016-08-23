class ManageIQ::Providers::Amazon::CloudManager::Template < ManageIQ::Providers::CloudManager::Template
  supports :provisioning do
    if ext_management_system
      unsupported_reason_add(:provisioning, ext_management_system.unsupported_reason(:provisioning)) unless ext_management_system.supports_provisioning?
    else
      unsupported_reason_add(:provisioning, _('not connected to ems'))
    end
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.image(ems_ref)
  end

  def proxies4job(_job = nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Image'
    }
  end

  def validate_smartstate_analysis
    validate_unsupported("Smartstate Analysis")
  end
end
