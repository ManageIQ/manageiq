$:.push("#{File.dirname(__FILE__)}/../../HyperV")

require 'rubygems'
require "win32/service"
require 'MiqHyperv'

class MSVirtualServerCom
	VBSCRIPT_EXE = "cscript"
	HELPER_SCRIPT = "MicrosoftWinCom.vbs"
	MSVS_SERVICE_NAME = "Virtual Server"

	# Constants
	#=====================================
	# VmExecutionState
	#=====================================
	VMVMSTATE_INVALID = 0
	VMVMSTATE_TURNEDOFF = 1
	VMVMSTATE_SAVED = 2
	VMVMSTATE_TURNINGON = 3
	VMVMSTATE_RESTORING = 4
	VMVMSTATE_RUNNING = 5
	VMVMSTATE_PAUSED = 6
	VMVMSTATE_SAVING = 7
	VMVMSTATE_TURNINGOFF = 8
	VMVMSTATE_MERGINGDRIVES = 9
	VMVMSTATE_DELETEMACHINE = 10

	def initialize(ost=nil)
    begin
      extend MSHyperV_Server
      self.init_hv()
      raise "Hyper-V not found" if hypervisorVersion().nil?
    rescue => err
      extend MSVirtualServer_Server
      self.init_hv()
      @server = MSVirtualServer_Server.new()
    end
	end
end # end MSVirtualServerCom

module MSVirtualServer_Server
  def init_hv()
    # Check to see if MS Virtual Service is install and running before we try to access the COM interface
    comStatus ||= Win32::Service.status(MSVS_SERVICE_NAME)
    raise "Microsoft Virtual Server not configured." unless comStatus && (comStatus.current_state === "running")
  end

	def registeredVms
    return @server.registeredVms if @server
		vms = []
		runCommand(["-l"]).each_line {|l| vms << l}
		return vms
	end

	def state(vmName)
		return State2Str(runVmCommand(["state", vmName]))
	end

	def start(vmName, mode=nil)
		# Depending on the current state we either need to call start or resume
		case (runVmCommand(["state", vmName]).to_i)
		when VMVMSTATE_PAUSED
			runVmCommand(["resume", vmName])
		else
			runVmCommand(["start", vmName])
		end
		return true
	end

	def stop(vmName, mode=nil)
		runVmCommand(["stop", vmName])
		return true
	end

	def suspend(vmName, mode=nil)
		runVmCommand(["suspend", vmName])
		return true
	end

	def reset(vmName, mode=nil)
		runVmCommand(["reset", vmName])
		return true
	end

	def hypervisorVersion()
    return @server.hypervisorVersion if @server
		va = runCommand(["-v"]).split(" ")
		{"vendor"=>va[0], "product"=>va[1].gsub("_", " "), "version"=>va[2], "build"=>va[3..-1].join(" ")}
	end

	def runVmCommand(parms)
		parms[1] = "\"#{File.basename(parms[1], ".vmc")}\""
		runCommand(parms)
	end

	def runCommand(parms)
		ret = ""
		script = File.join(File.dirname(__FILE__), HELPER_SCRIPT)
		script_ret = `#{VBSCRIPT_EXE} #{script} #{parms.join(" ")}`
		script_ret.each_line {|l|
			l.strip!
			next if l.empty?
			next if l.include?("Microsoft (R) Windows Script Host")
			next if l.include?("Copyright (C) Microsoft Corporation")

			ret += "#{l}\n"
		}
		ret
	end

	def State2Str(intState)
		#	VMVMSTATE_INVALID
		#	VMVMSTATE_MERGINGDRIVES
		#	VMVMSTATE_DELETEMACHINE

		case (intState.to_i)
		when VMVMSTATE_TURNINGON, VMVMSTATE_RUNNING, VMVMSTATE_RESTORING
			return "on"
		when VMVMSTATE_TURNEDOFF, VMVMSTATE_TURNINGOFF
			return "off"
		when VMVMSTATE_SAVED, VMVMSTATE_PAUSED, VMVMSTATE_SAVING
			return "suspended"
		when VMVMSTATE_INVALID  #???
			return "stuck"
		else
			return "unknown"
		end
	end
end

module MSHyperV_Server
  def init_hv()
    @hyperv = MiqHyperV.new()
    @hyperv.connect
  end

  def hypervisorVersion()
    @hyperv.hypervisorVersion()
  end

  def registeredVms()
    @hyperv.registeredVms()
  end

  def state(vmName)
    @hyperv.getVm(vmName).powerState
  end

	def start(vmName, mode=nil)
    @hyperv.getVm(vmName).start
	end

	def stop(vmName, mode=nil)
    @hyperv.getVm(vmName).stop
	end

	def suspend(vmName, mode=nil)
    @hyperv.getVm(vmName).suspend
	end

	def pause(vmName, mode=nil)
    @hyperv.getVm(vmName).pause
	end

	def reset(vmName, mode=nil)
    @hyperv.getVm(vmName).reset
	end

	def shutdownGuest(vmName, mode=nil)
    @hyperv.getVm(vmName).shutdownGuest
	end

	def standbyGuest(vmName, mode=nil)
    @hyperv.getVm(vmName).standbyGuest
	end

	def rebootGuest(vmName, mode=nil)
    @hyperv.getVm(vmName).rebootGuest
	end

  def create_snapshot(vmName, name, description)
    @hyperv.getVm(vmName).createSnapshot(name, description)
  end

  def remove_snapshot(vmName, sn_uid)
    @hyperv.getVm(vmName).removeSnapshot(sn_uid)
  end

  def remove_all_snapshots(vmName)
    @hyperv.getVm(vmName).removeAllSnapshots()
  end

  def revert_to_snapshot(vmName, sn_uid)
    @hyperv.getVm(vmName).revertToSnapshot(sn_uid)
  end

  def remove_snapshot_by_description(vmName, description)
    @hyperv.getVm(vmName).removeSnapshotByDescription(description)
  end

  def to_inv_h
    invh = {:vms=>[]}
    vms = self.registeredVms
    vms.each do |v|
        invh[:vms] << {:location => v, :power_state => self.state(v), :name => File.basename(v, '.xml')}
    end
    return invh
  end

  def MonitorEmsEvents(ost)
    require 'EventingOps'
    EmsEventMonitorOps.doEvents(ost, self.class)
    # Does not return
  end

  def GetEmsInventory(ost)
    ems_hash = MiqHypervInventoryParser.ems_inv_to_hashes(@hyperv.ems_refresh())
    ems_hash[:type] = :ems_refresh
    ost.yaml = true
    ost.encode = true
    ost.value = YAML.dump(ems_hash)
  end
end

if __FILE__ == $0 then
  begin    
    hyperv = MSVirtualServerCom.new rescue nil
    if hyperv
      p hyperv.hypervisorVersion
      vms = hyperv.registeredVms
      p vms

      vms.each {|v| puts "State:[#{hyperv.state(v)}]  VM:[#{v}]"}
#      p vms.start(vmName)
#      puts vms.state(vmName)
#      p vms.stop(vmName)
    end
  rescue Exception
    puts $!
  end
	p "done"
end
