class ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneVolume < ::AvailabilityZone
  has_many   :cloud_volumes, :class_name => "ManageIQ::Providers::Openstack::CloudManager::CloudVolume"
end
