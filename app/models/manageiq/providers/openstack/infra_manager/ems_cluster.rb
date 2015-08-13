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

  ############################################33
  # OpenStack status aggregate methods
  def service_groups
    self.hosts.joins(:host_service_groups)
  end

  def service_group_services
    self.hosts.joins(:host_service_groups => :system_services)
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
end
