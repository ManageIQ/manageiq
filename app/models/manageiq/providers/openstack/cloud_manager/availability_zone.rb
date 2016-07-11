class ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone < ::AvailabilityZone
  # TODO: Currently, all cinder nodes are installed with the default availability zone,
  # nova. So we just take the aggregate disk capacity in the BlockStorage cluster.
  # In the future, when multiple Cinder availability zones are supported in the overcloud
  # deployment, this needs to be changed so that we only sum up the disk capacities for
  # hosts that has the matching availability_zone configured in /etc/cinder/cinder.conf.
  def block_storage_disk_capacity
    cluster = ext_management_system.provider.infra_ems.ems_clusters.find { |c| c.block_storage? == true }
    cluster.nil? ? 0 : cluster.aggregate_disk_capacity
  end

  def block_storage_disk_usage
    cloud_volumes.where.not(:status => "error").sum(:size).to_f
  end
end
