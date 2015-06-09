class HostServiceGroupOpenstack < HostServiceGroup
  def running_system_services_condition
    # UI can't do arel relations, so I need to expose conditions
    SystemService.running_systemd_services_condition
  end

  def failed_system_services_condition
    # UI can't do arel relations, so I need to expose conditions
    SystemService.failed_systemd_services_condition
  end

  def host_service_group_system_services_condition
    SystemService.host_service_group_condition(self.id)
  end

  def host_service_group_filesystems_condition
    Filesystem.host_service_group_condition(self.id)
  end

  def running_system_services
    system_services.where(running_system_services_condition)
  end

  def failed_system_services
    system_services.where(failed_system_services_condition)
  end
end
