class MiqWorker
  module SystemdCommon
    extend ActiveSupport::Concern

    class_methods do
      def ensure_systemd_files
        target_file_path.write(target_file) unless target_file_path.exist?
        service_file_path.write(unit_file) unless service_file_path.exist?
        FileUtils.mkdir_p(service_config_path) unless service_config_path.exist?
        service_config_file_path.write(service_settings_file) unless service_config_file_path.exist?
      end

      def service_base_name
        minimal_class_name.underscore.tr("/", "_")
      end

      def slice_base_name
        "miq"
      end

      def service_name
        singleton_worker? ? service_base_name : "#{service_base_name}@"
      end

      def service_file_name
        "#{service_name}.service"
      end

      def slice_name
        "#{slice_base_name}-#{service_base_name}.slice"
      end

      def service_file_path
        systemd_unit_dir.join(service_file_name)
      end

      def service_config_name
        "#{service_file_name}.d"
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
        Pathname.new("/etc/systemd/system")
      end

      def target_file
        <<~TARGET_FILE
          [Unit]
          PartOf=miq.target
        TARGET_FILE
      end

      def unit_file
        <<~UNIT_FILE
          [Unit]
          PartOf=#{target_file_name}
          [Install]
          WantedBy=#{target_file_name}
          [Service]
          Environment=HOME=/root
          WorkingDirectory=#{working_directory}
          ExecStart=/bin/bash -lc '#{exec_start}'
          Restart=always
          Slice=#{slice_name}
        UNIT_FILE
      end

      def working_directory
        # TODO: pull this dynamically
        "/var/www/miq/vmdb"
      end

      def exec_start
        "exec ruby lib/workers/bin/run_single_worker.rb #{name} #{run_single_worker_args}"
      end

      def run_single_worker_args
        "--heartbeat --guid=%i"
      end

      def service_environment_variables
        # Override this in a child class to add env vars
        []
      end

      def service_settings_file
        <<~WORKER_SETTINGS_FILE
          [Service]
          #{service_environment_variables.map { |env_var| "Environment=#{env_var}" }.join("\n")}
          MemoryHigh=#{worker_settings[:memory_threshold].bytes}
          TimeoutStartSec=#{worker_settings[:starting_timeout]}
          TimeoutStopSec=#{worker_settings[:stopping_timeout]}
        WORKER_SETTINGS_FILE
      end
    end

    def start_systemd_worker
      enable_systemd_unit
      write_unit_settings_file unless singleton_worker?
      start_systemd_unit
    end

    def stop_systemd_worker
      stop_systemd_unit
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

    private

    def systemd
      @systemd ||= begin
        require "dbus/systemd"
        DBus::Systemd::Manager.new
      end
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

    def write_unit_settings_file
      return unless unit_config_file.present?

      FileUtils.mkdir_p(unit_config_path) unless unit_config_path.exist?
      unit_config_file_path.write(unit_config_file) unless unit_config_file_path.exist?
    end

    def unit_config_name
      "#{unit_name}.d"
    end

    def unit_config_path
      self.class.systemd_unit_dir.join(unit_config_name)
    end

    def unit_config_file_path
      unit_config_path.join("settings.conf")
    end

    def unit_config_file
      # Override this in a sub-class if the specific instance needs
      # any additional config
      nil
    end
  end
end
