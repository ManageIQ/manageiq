class ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone < ::AvailabilityZone
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.availability_zones[ems_ref]
  end
end
