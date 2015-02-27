module ManageiqForeman
  class Host
    attr_accessor :manager_ref
    attr_accessor :connection

    def initialize(connection, manager_ref)
      @connection = connection
      @manager_ref = manager_ref
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

    def powered_on?
      power_state == "on"
    end

    def reboot(mode = "pxe")
      connection.fetch(:hosts, :boot, "id" => manager_ref, "device" => mode)
    end

    def update(params)
      connection.fetch(:hosts, :update, params.merge("id" => manager_ref))
    end
  end
end
