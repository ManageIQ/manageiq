class HostRedhat < Host
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.get_resource_by_ems_ref(ems_ref)
  end

  def verify_credentials(auth_type=nil, options={})
    raise MiqException::MiqHostError, "No credentials defined" if self.authentication_invalid?(auth_type)
    raise MiqException::MiqHostError, "Logon to platform [#{self.os_image_name}] not supported" if auth_type.to_s != 'ipmi' && self.os_image_name !~ /linux_*/

    case auth_type.to_s
    when 'ipmi' then verify_credentials_with_ipmi(auth_type)
    else
      verify_credentials_with_ssh(auth_type, options)
    end

    return true
  end
end
