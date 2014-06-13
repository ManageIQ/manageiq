module MiqLibvirt
  class Vm
    def initialize(invObj, vmh)
      unless invObj.nil?
        @invObj                 = invObj
        @vmService              = invObj.vmService
        @sic                    = invObj.sic
      end

      init(vmh)
    end

    def init(vmh)
      if vmh.empty?
        @props = {}
        return
      end

      @props                  = vmh
#      @name                   = @props[:Name]
      @uuid                   = @props[:uuid]
#      @vmMor                  = @props[:VMId]
#      @dsPath                 = @props[:VMCPath]
#      @hostSystem             = @props[:HostName]
#      @localPath              = @props[:VMCPath]
    end

    def start
      change_state(:start)
    end

    def stop
      change_state(:stop)
    end

    def shutdownGuest
      change_state(:shutdownGuest)
    end

    def suspend
      change_state(:save_state)
    end

    def pause
      change_state(:suspend)
    end

    def change_state(newState)
      @props[:StatusString] = @vmService.send(newState, @uuid)
      return powerState
    end

    def self.powerState(value, domain=nil)
      state = case value.to_s.downcase
              when "running"  then "on"
              when "blocked"  then "suspended"
              when "paused"   then "paused"
              when "shutdown", "crashed", "dying", "shut off" then "off"
              else value.to_s
              end

      # If the VM is off, but a saved_state file exists, then we can restore from that point
      state = "suspended" if state == "off" && !domain.nil? && domain[:saved_state_exists] == true
       
      return state
    end

    def powerState()
      self.class.powerState(@props[:StatusString])
    end

    def poweredOn?
      powerState == "on"
    end

    def poweredOff?
      powerState == "off"
    end

    def suspended?
      powerState == "suspended"
    end

    def connectionState
      true
    end
  end # class MiqLibvirtVm
end # module MiqLibvirt