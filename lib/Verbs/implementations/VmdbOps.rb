$:.push("#{File.dirname(__FILE__)}/../../blackbox")
$:.push("#{File.dirname(__FILE__)}/../../util/diag")

require 'ostruct'
require 'rubygems'
require 'VmBlackBox'
require 'VmwareOps'
require 'miqping'

begin
  # Try to load through Rails autoload if running under Rails
  MiqservicesClient
rescue NameError
  # Load it directly, since we are not in a Rails env
  require 'action_web_service'

  $:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. vmdb app apis})))
  require 'evm_webservices_client'
  require 'miqservices_client'
  require 'miqservices_api'
end

class VmdbOps
    def initialize(ost)
        cfg = ost.config
        @vmdbDriver ||= MiqservicesClient.new("#{cfg.vmdbHost}:#{cfg.vmdbPort}", cfg.webservices[:consumer_protocol])
    end # def initilaize
    
    def startService(ost)
        raise "No service name specified" if ost.service.nil?
        raise "No userid specified"       if ost.userid.nil?
        
        ost.value = @vmdbDriver.StartService(ost.service, ost.userid, "now")
    end # def startService
	
	def policyCheckVmInternal(ost)
    vmName = getVmFile(ost)
    vmId = ost.args[1]

		vmId = Manageiq::BlackBox.vmId(vmName) if vmId.nil?
		ret = @vmdbDriver.PolicyCheckVm(vmId, "")
		ret, reason = eval(ret)
		raise "VM policy check failed for [#{vmName}] reason [#{reason}]" if ret == false
	end
	
	#
	# Called by miqhost to return policy evaluation from the VMDB
	# to the caller (miq-cmd).
	#
	def PolicyCheckVm(ost)
		vmName = getVmFile(ost)
		vmId = Manageiq::BlackBox.vmId(vmName)
		ret = @vmdbDriver.PolicyCheckVm(vmId, "")
		ret, reason = eval(ret)
		
		$log.info "PolicyCheckVm: ret = #{ret}, reason = #{reason}, vmId = #{vmId}, vm = #{vmName}" if $log
		
		if ret == false
		    # VM policy check failed
		    ost.value = 1
        else
            # VM policy check succeeded
            ost.value = 0
        end
	end
	
	def SaveEmsInventory(ost)
		hostId = ost.args[0]

		@vmdbDriver.SaveXmldata(hostId, ost.args[1])
		ost.value = "OK\n"
	end
	
	def SendEmsEvents(ost)
		hostId = ost.args[0]

		@vmdbDriver.SaveXmldata(hostId, ost.args[1])
		ost.value = "OK\n"
	end

	def AgentRegister(ost)
		ost.value = @vmdbDriver.AgentRegister(ost.args[0].to_s)
	end

	def AgentUnregister(ost)
		ost.value = @vmdbDriver.AgentUnregister(ost.args[0].to_s, ost.args[1].to_s)
	end

	def AgentConfig(ost)
		ost.value = @vmdbDriver.AgentConfig(ost.args[0], ost.args[1].to_s)
	end
	
	#
	# These are VMDB specific operations, but we may need to handle the
	# VM file in some VM type specific way.
	#
	# This routine is intended to provide a VM type switch in the
	# context of this class.
	
	def getVmFile(ost)
	    VMWareOps.getVmFile(ost)
	end
	
	def getVmMdFile(vmName, sfx)
		ext = File.extname(vmName)
		fbn = File.basename(vmName, ext)
		dir = File.dirname(vmName)

		File.join(dir, fbn + "_" + sfx)
	end	
	
	def ServerPing(ost)
		Manageiq::MiqWsPing.ping(ost.pingCfg)
	end

	def QueueAsyncResponse(ost)
		queue_parms = ost.args[0]
		data = ost.args[1]
		ost.value = @vmdbDriver.QueueAsyncResponse(queue_parms, data)
	end  
end # class VmdbOps
