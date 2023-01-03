class MiqServer::WorkerManagement::Systemd < MiqServer::WorkerManagement
  def sync_from_system
    self.miq_services = systemd_services.select { |unit| manageiq_service?(unit) }
    self.miq_services_by_guid = miq_services.index_by { |w| w[:name].match(/^.+@(?<guid>.+)\.service$/).named_captures["guid"] }
  end

  def sync_starting_workers!(starting)
    sync_from_system
    starting.each do |worker|
      next if worker.class.rails_worker?

      systemd_worker = miq_services_by_guid[worker[:guid]]
      if systemd_worker[:load_state] == "loaded" && systemd_worker[:active_state] == "active" && systemd_worker[:sub_state] == "running"
        worker.update!(:status => "started")
        starting.delete(worker)
      end
    end
  end

  def cleanup_failed_workers
    super

    cleanup_failed_systemd_services
  end

  def cleanup_failed_systemd_services
    service_names = failed_miq_service_namees
    return if service_names.empty?

    _log.info("Disabling failed unit files: [#{service_names.join(", ")}]")
    systemd_stop_services(service_names)
  end

  private

  attr_accessor :miq_services, :miq_services_by_guid

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
    Pathname.new("/lib/systemd/system")
  end

  def manageiq_service?(unit)
    manageiq_service_base_names.include?(systemd_service_base_name(unit))
  end

  def manageiq_service_base_names
    @manageiq_service_base_names ||= MiqWorkerType.worker_classes.map(&:service_base_name)
  end

  def systemd_service_name(unit)
    File.basename(unit[:name], ".*")
  end

  def systemd_service_base_name(unit)
    systemd_service_name(unit).split("@").first
  end

  def failed_miq_services
    miq_services.select { |service| service[:active_state] == "failed" }
  end

  def failed_miq_service_namees
    failed_miq_services.pluck(:name)
  end

  def systemd_services
    systemd_units.select { |unit| File.extname(unit[:name]) == ".service" }
  end

  def systemd_units
    systemd_manager.units
  end
end
