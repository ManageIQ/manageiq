class ManageIQ::Providers::Openstack::InfraManager::EmsCluster < ::EmsCluster
  def direct_vms
    vms
  end

  # Direct Vm relationship methods
  def direct_vm_rels
    # Look for only the Vms at the second depth (default RP + 1)
    direct_vms
  end

  def direct_vm_ids
    direct_vms.collect(&:id)
  end

  # ###########################################33
  # OpenStack status aggregate methods
  def service_groups
    hosts.joins(:host_service_groups)
  end

  def service_group_services
    hosts.joins(:host_service_groups => :system_services)
  end

  def service_group_names
    service_groups.group('host_service_groups.name').select('host_service_groups.name')
  end

  def service_group_services_running
    service_group_services.where(SystemService.running_systemd_services_condition)
  end

  def service_group_services_failed
    service_group_services.where(SystemService.failed_systemd_services_condition)
  end

  def host_ids_with_running_service_group(service_group_name)
    service_group_services_running.where('host_service_groups.name' => service_group_name).select('DISTINCT hosts.id')
  end

  def host_ids_with_failed_service_group(service_group_name)
    service_group_services_failed.where('host_service_groups.name' => service_group_name).select('DISTINCT hosts.id')
  end

  def host_ids_with_service_group(service_group_name)
    service_group_services.where('host_service_groups.name' => service_group_name).select('DISTINCT hosts.id')
  end

  # TODO: Add support for Ceph
  def block_storage?
    name.include?("BlockStorage")
  end

  # TODO: Add support for Ceph
  def object_storage?
    name.include?("ObjectStorage")
  end

  def compute?
    name.include?("Compute")
  end

  def controller?
    name.include?("Controller")
  end

  # TODO: Assumes there is a single overcloud. Will need
  # to change this once we support multiple overclouds.
  def cloud
    ext_management_system.provider.cloud_ems.first
  end

  def cloud_block_storage_disk_usage
    cloud.block_storage_disk_usage
  end

  def cloud_object_storage_disk_usage
    stack = ext_management_system.orchestration_stacks.find_by(:name => cloud.name)
    replicas = stack.parameters.find_by(:name => 'SwiftReplicas').value.to_i
    object_storage_count = stack.parameters.find_by(:name => 'ObjectStorageCount').value.to_i
    # The number of replicas depends on what was configured in swift as replicas
    # and the number of object storage nodes deployed. The actual number of replicas
    # is the minimum between the configured replicas and object storage nodes.
    # Note the controller node currently also serves as a swift storage node. So
    # this doesn't reflect true disk usage over the entire overcloud.
    cloud.object_storage_disk_usage([replicas, object_storage_count].min)
  end
end
