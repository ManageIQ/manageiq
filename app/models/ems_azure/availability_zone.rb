class EmsAzure::AvailabilityZone < ::AvailabilityZone
  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.availability_zones[self.ems_ref]
  end
end
