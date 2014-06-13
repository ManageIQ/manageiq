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
      LinuxAdmin.run("chkconfig", :params => {"--add" => "miqtop"})  # Is this really needed?
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

    def service_command(action)
      services = send("to_#{action}")
      services.each {|s| LinuxAdmin::Service.new(s).send(action)}
    end

    #TODO: Fix LinuxAdmin::Service to detach.
    def start_command
      to_start.each {|s| Process.detach(Kernel.spawn("/sbin/service #{s} start", [:out, :err] => ["/dev/null", "w"]))}
    end
  end
end