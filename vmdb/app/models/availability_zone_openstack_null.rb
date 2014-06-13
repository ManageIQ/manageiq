# An availability zone to represent the cases where Openstack VMs may be
# launched into no availability zone
class AvailabilityZoneOpenstackNull < AvailabilityZoneOpenstack
  default_value_for :name,   "No Availability Zone"
end
