class HostServiceGroupOpenstack < HostServiceGroup
  def running_system_services_condition
    # UI can't do arel relations, so I need to expose conditions
    ["systemd_active= ? AND systemd_sub=?", 'active', 'running']
  end

  def failed_system_services_condition
    # UI can't do arel relations, so I need to expose conditions
    ["(systemd_active= ? OR systemd_sub=?)", 'failed', 'failed']
  end

  def running_system_services
    system_services.where(running_system_services_condition)
  end

  def failed_system_services
    system_services.where(failed_system_services_condition)
  end
end
