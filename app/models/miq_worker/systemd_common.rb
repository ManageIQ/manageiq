class MiqWorker
  module SystemdCommon
    extend ActiveSupport::Concern

    class_methods do
      def service_base_name
        "manageiq-#{minimal_class_name.underscore.tr("/", "_")}"
      end

      def service_file
        "#{service_base_name}@.service"
      end

      def target_file
        "#{service_base_name}.target"
      end

      def systemd_unit_dir
        Pathname.new("/lib/systemd/system")
      end
    end

    def unit_name
      "#{service_base_name}#{unit_instance}.service"
    end

    def start_systemd_worker
      enable_systemd_unit
      write_unit_settings_file
      start_systemd_unit
    end

    def stop_systemd_worker
      stop_systemd_unit
      cleanup_unit_settings_file
      disable_systemd_unit
    end

    def enable_systemd_unit(runtime: false, replace: true)
      systemd.EnableUnitFiles([unit_name], runtime, replace)
    end

    def disable_systemd_unit(runtime: false)
      systemd.DisableUnitFiles([unit_name], runtime)
    end

    def start_systemd_unit(mode: "replace")
      systemd.StartUnit(unit_name, mode)
    end

    def stop_systemd_unit(mode: "replace")
      systemd.StopUnit(unit_name, mode)
    end

    def sd_notify_started
      sd_notify.ready
    end

    def sd_notify_stopping
      sd_notify.stopping
    end

    def sd_notify_watchdog
      sd_notify.watchdog
    end

    def sd_notify_watchdog_usec(timeout_in_seconds)
      usec = timeout_in_seconds * 1_000_000
      sd_notify.notify("WATCHDOG_USEC=#{usec}", false)
    end

    private

    def systemd
      @systemd ||= begin
        require "dbus/systemd"
        DBus::Systemd::Manager.new
      end
    end

    def sd_notify
      @sd_notify ||= begin
        require "sd_notify"
        SdNotify
      end
    end

    def service_base_name
      self.class.service_base_name
    end

    def unit_instance
      "@#{guid}"
    end

    def write_unit_settings_file
      FileUtils.mkdir_p(unit_config_path)           unless unit_config_path.exist?
      unit_config_file_path.write(unit_config_file) unless unit_config_file_path.exist?
    end

    def cleanup_unit_settings_file
      unit_config_file_path.delete if unit_config_file_path.exist?
      unit_config_path.delete      if unit_config_path.exist?
    end

    def unit_config_name
      "#{unit_name}.d"
    end

    def unit_config_path
      self.class.systemd_unit_dir.join(unit_config_name)
    end

    def unit_config_file_path
      unit_config_path.join("override.conf")
    end

    def unit_config_file
      <<~UNIT_CONFIG_FILE
        [Service]
        #{unit_settings.compact.map              { |key, value| "#{key}=#{value}" }.join("\n")}
        #{unit_environment_variables.compact.map { |key, value| "Environment=#{key}=#{value}" }.join("\n")}
      UNIT_CONFIG_FILE
    end

    # Override this in a sub-class if the specific instance needs
    # any additional configuration settings
    def unit_settings
      {
        "MemoryHigh"      => worker_settings[:memory_threshold]&.bytes,
        "TimeoutStartSec" => worker_settings[:starting_timeout],
        "TimeoutStopSec"  => worker_settings[:stopping_timeout],
        "WatchdogSec"     => worker_settings[:heartbeat_timeout]
      }
    end

    # Override this in a child class to add environment variables
    def unit_environment_variables
      {}
    end
  end
end
