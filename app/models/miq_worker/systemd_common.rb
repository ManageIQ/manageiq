class MiqWorker
  module SystemdCommon
    extend ActiveSupport::Concern

    class_methods do
      def supports_systemd?
        return unless worker_settings[:systemd_enabled]
        require "dbus/systemd"
        true
      rescue LoadError
        false
      end

      def ensure_systemd_files
        target_file_path.write(target_file)
        service_file_path.write(unit_file)
      end

      def service_base_name
        minimal_class_name.underscore.tr("/", "_")
      end

      def slice_base_name
        "miq"
      end

      def service_name
        "#{service_base_name}@"
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
          WorkingDirectory=#{working_directory}
          Environment=BUNDLER_GROUPS=#{bundler_groups.join(",")}
          ExecStart=/bin/bash -lc '#{exec_start}'
          Restart=no
          Slice=#{slice_name}
        UNIT_FILE
      end

      def working_directory
        Rails.root
      end

      def exec_start
        "exec ruby lib/workers/bin/run_single_worker.rb #{name} #{run_single_worker_args}"
      end

      def run_single_worker_args
        "--heartbeat --guid=%i"
      end
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
      # Override this in a sub-class if the specific instance needs
      # any additional config
      <<~UNIT_CONFIG_FILE
        [Service]
        MemoryHigh=#{worker_settings[:memory_threshold].bytes}
        TimeoutStartSec=#{worker_settings[:starting_timeout]}
        TimeoutStopSec=#{worker_settings[:stopping_timeout]}
        #{unit_environment_variables.map { |env_var| "Environment=#{env_var}" }.join("\n")}
      UNIT_CONFIG_FILE
    end

    def unit_environment_variables
      # Override this in a child class to add env vars
      [
        "HOME=/root"
      ]
    end
  end
end
