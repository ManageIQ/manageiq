class VmOpenstack < VmCloud
  include_concern 'Operations'

  belongs_to :cloud_tenant

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.servers.get(self.ems_ref)
  end
end
