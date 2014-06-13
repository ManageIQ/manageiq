class TemplateRedhat < TemplateInfra
  def self.supports_kickstart_provisioning?
    true
  end

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.get_resource_by_ems_ref(self.ems_ref)
  end
end
