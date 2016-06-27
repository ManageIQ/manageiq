class ManageIQ::Providers::Openstack::CloudManager::HostAggregate < ::HostAggregate
  store :metadata, :accessors => [:availability_zone]

  # if availability zone named in metadata exists, return it
  def availability_zone_obj
    AvailabilityZone.find_by_ems_ref_and_ems_id(availability_zone, ems_id)
  end
end
