module ManageiqForeman
  class Host
    attr_accessor :manager_ref
    attr_accessor :connection

    def initialize(connection, manager_ref)
      @connection = connection
      @manager_ref = manager_ref
    end

    def building?
      attributes["build"]
    end

    def start
      power_state("on")
    end

    def stop
      power_state("off")
    end

    # valid actions are (on/start), (off/stop), (soft/reboot), (cycle/reset), (state/status)
    def power_state(action = "status")
      connection.fetch(:hosts, :power, "id" => manager_ref, "power_action" => action).first["power"]
    end

    def powered_off?
      power_state == "off"
    end

    def powered_on?
      power_state == "on"
    end

    def set_boot_mode(mode = "pxe")
      connection.fetch(:hosts, :boot, "id" => manager_ref, "device" => mode).first["boot"]
    end

    def attributes
      connection.fetch(:hosts, :show, "id" => manager_ref).first
    end

    def update(params)
      connection.fetch(:hosts, :update, "id" => manager_ref, "host" => params)
    end
  end
end
