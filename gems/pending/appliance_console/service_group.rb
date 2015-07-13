module ApplianceConsole
  POSTGRESQL_SERVICE = "postgresql92-postgresql".freeze

  class ServiceGroup
    SERVICES  = %w{evminit memcached miqtop evmserverd}.freeze

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
      enable_miqtop
      SERVICES.each { |s| run_service(s, "enable") }
      run_service(POSTGRESQL_SERVICE, "enable") if postgresql?
    end

    def disable
      run_service(POSTGRESQL_SERVICE, "disable") unless postgresql?
    end

    def start
      SERVICES.each { |s| run_detached_service(s, "start") }
    end

    def stop
      run_service(POSTGRESQL_SERVICE, "stop") unless postgresql?
    end

    private

    def enable_miqtop
      LinuxAdmin.run("chkconfig", :params => {"--add" => "miqtop"})  # Is this really needed?
    end

    def run_service(service, action)
      LinuxAdmin::Service.new(service).send(action)
    end

    #TODO: Fix LinuxAdmin::Service to detach.
    def run_detached_service(service, action)
      Process.detach(Kernel.spawn("/sbin/service #{service} #{action}", [:out, :err] => ["/dev/null", "w"]))
    end
  end
end
