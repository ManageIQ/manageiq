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

    def to_enable
      postgresql? ? SERVICES + [POSTGRESQL_SERVICE] : SERVICES.dup
    end

    def to_disable
      postgresql? ? [] : [POSTGRESQL_SERVICE]
    end
    alias :to_stop :to_disable

    def to_start
      SERVICES.dup
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
      service_command("enable")
    end

    def disable
      service_command("disable")
    end

    def start
      start_command
    end

    def stop
      service_command("stop")
    end

    private

    def enable_miqtop
      LinuxAdmin.run("chkconfig", :params => {"--add" => "miqtop"})  # Is this really needed?
    end

    def run_service(service, action)
      LinuxAdmin::Service.new(service).send(action)
    end

    def service_command(action)
      services = send("to_#{action}")
      services.each {|s| run_service(s, action) }
    end

    #TODO: Fix LinuxAdmin::Service to detach.
    def start_command
      to_start.each {|s| Process.detach(Kernel.spawn("/sbin/service #{s} start", [:out, :err] => ["/dev/null", "w"]))}
    end
  end
end