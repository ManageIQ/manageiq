require 'rubygems'
require "win32/service"

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
    extend MSVirtualServer_Server
    self.init_hv()
    @server = MSVirtualServer_Server.new()
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
