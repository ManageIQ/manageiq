require "dbus/systemd"

class MiqWorker
  module SystemdWorker
    extend ActiveSupport::Concern

    class_methods do
      def supports_systemd?
        true
      end

      def sync_workers
        ensure_systemd_files
        super
      end

      def ensure_systemd_files
        File.write(target_file_path, target_file) unless target_file_path.exist?
        File.write(service_file_path, unit_file) unless service_file_path.exist?
        Dir.mkdir(service_config_path) unless service_config_path.exist?
        File.write(service_config_file_path, service_settings_file) unless service_config_file_path.exist?
      end

      def service_base_name
        "#{minimal_class_name.underscore.tr("/", "_")}"
      end

      def service_name
        singleton_worker? ? "#{service_base_name}" : "#{service_base_name}@"
      end

      def service_file_name
        "#{service_name}.service"
      end

      def slice_name
        "cfme-#{service_name}.slice"
      end

      def service_file_path
        systemd_unit_dir.join(service_file_name)
      end

      def service_config_name
        "#{service_name}.d"
      end

      def service_config_path
        systemd_unit_dir.join(service_config_name)
      end

      def service_config_file_path
        service_config_path.join("settings.conf")
      end

      def target_file_name
        "#{service_base_name}.target"
      end

      def target_file_path
        systemd_unit_dir.join(target_file_name)
      end

      def systemd_unit_dir
        Pathname.new("/").join("etc", "systemd", "system")
      end

      def target_file
        <<~TARGET_FILE
          [Unit]
          PartOf=cfme.target
        TARGET_FILE
      end

      def unit_file
        <<~UNIT_FILE
          [Unit]
          PartOf=#{target_file_name}
          [Install]
          WantedBy=#{target_file_name}
          [Service]
          #{unit_environment_variables.join("\n")}
          WorkingDirectory=#{working_directory}
          ExecStart=/bin/bash -lc 'exec ruby lib/workers/bin/run_single_worker.rb #{self.class.name} --heartbeat'
          Restart=always
          Slice=#{slice_name}
        UNIT_FILE
      end

      def unit_environment_variables
        # TODO get user's home dir dynamically
        ["Environment=HOME=/root"]
      end

      def service_settings_file
        <<~WORKER_SETTINGS_FILE
          [Service]
          MemoryHigh=#{worker_settings[:memory_threshold].bytes}
          TimeoutStartSec=#{worker_settings[:starting_timeout]}
          TimeoutStopSec=#{worker_settings[:stopping_timeout]}
        WORKER_SETTINGS_FILE
      end

      def working_directory
        # TODO pull this dynamically
        "/var/www/miq/vmdb"
      end
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

    private

    def systemd
      @systemd ||= DBus::Systemd::Manager.new
    end

    def service_base_name
      self.class.service_base_name
    end

    def unit_name
      "#{service_base_name}#{unit_instance}.service"
    end

    def unit_instance
      singleton_worker? ? "" : "@#{guid}"
    end
  end
end
