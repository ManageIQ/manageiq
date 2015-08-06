# An availability zone to represent the cases where Openstack VMs may be
# launched into no availability zone
class ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull < ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone
  default_value_for :name,   "No Availability Zone"
end
