require "appliance_console/internal_database_configuration"
require "util/postgres_admin"

module ApplianceConsole
  class ServiceGroup
    SERVICES  = %w(evmserverd).freeze

    def initialize(hash = {})
      @postgresql = hash[:internal_postgresql]
    end

    def postgresql?
      !!@postgresql
    end

    def restart_services
      enablement
      restart
    end

    def enablement
      disable
      enable
    end

    def restart
      stop
      start
    end

    def enable
      SERVICES.each { |s| run_service(s, "enable") }
      run_service(PostgresAdmin.service_name, "enable") if postgresql?
    end

    def disable
      run_service(PostgresAdmin.service_name, "disable") unless postgresql?
    end

    def start
      SERVICES.each { |s| run_service(s, "start") }
    end

    def stop
      run_service(PostgresAdmin.service_name, "stop") unless postgresql?
    end

    private

    def run_service(service, action)
      LinuxAdmin::Service.new(service).send(action)
    end
  end
end
