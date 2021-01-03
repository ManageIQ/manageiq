module MiqServer::WorkerManagement::Monitor::Systemd
  extend ActiveSupport::Concern

  def cleanup_failed_systemd_services
    failed_service_names = systemd_failed_miq_services.map { |service| service[:name] }
    return if failed_service_names.empty?

    _log.info("Disabling failed unit files: [#{failed_service_names.join(", ")}]")
    systemd_stop_services(failed_service_names)
  end

  def systemd_failed_miq_services
    miq_services(systemd_failed_services)
  end

  def systemd_all_miq_services
    miq_services(systemd_services)
  end

  private

  def systemd_manager
    @systemd_manager ||= begin
      require "dbus/systemd"
      DBus::Systemd::Manager.new
    end
  end

  def systemd_stop_services(service_names)
    service_names.each do |service_name|
      systemd_manager.StopUnit(service_name, "replace")
      systemd_manager.ResetFailedUnit(service_name)

      service_settings_dir = systemd_unit_dir.join("#{service_name}.d")
      FileUtils.rm_r(service_settings_dir) if service_settings_dir.exist?
    end

    systemd_manager.DisableUnitFiles(service_names, false)
  end

  def systemd_unit_dir
    Pathname.new("/etc/systemd/system")
  end

  def miq_services(services)
    services.select { |unit| systemd_miq_service_base_names.include?(systemd_service_base_name(unit)) }
  end

  def systemd_miq_service_base_names
    @systemd_miq_service_base_names ||= begin
      MiqWorkerType.worker_class_names.map(&:constantize).map(&:service_base_name)
    end
  end

  def systemd_service_name(unit)
    File.basename(unit[:name], ".*")
  end

  def systemd_service_base_name(unit)
    systemd_service_name(unit).split("@").first
  end

  def systemd_failed_services
    systemd_services.select { |service| service[:active_state] == "failed" }
  end

  def systemd_services
    systemd_units.select { |unit| File.extname(unit[:name]) == ".service" }
  end

  def systemd_units
    systemd_manager.units
  end
end
