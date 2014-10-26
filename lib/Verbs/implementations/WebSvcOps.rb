$:.push("#{File.dirname(__FILE__)}/../../util")

require 'soap/wsdlDriver'
require 'soap/rpc/driver'

class WebSvcOps
  def initialize(ost)
    if ost.verbose
      puts "Host: #{ost.host}, Port: #{ost.port}"
    end
        
    proto = VMDB::Config.new("vmdb").config[:webservices][:consume_protocol] rescue "https"
    @driver = SOAP::RPC::Driver.new("#{proto}://#{ost.host}:#{ost.port}", "urn:Miqws")

    ost.connect_timeout ||= 120
    ost.send_timeout ||= 120
    ost.receive_timeout ||= 120
    @driver.options["protocol.http.connect_timeout"] = ost.connect_timeout
    @driver.options["protocol.http.send_timeout"] = ost.send_timeout
    @driver.options["protocol.http.receive_timeout"] = ost.receive_timeout
    @driver.options["protocol.http.ssl_config.verify_mode"] = ::OpenSSL::SSL::VERIFY_NONE if proto == "https"
    @driver.options["protocol.http.ssl_config.verify_callback"] = method(:verify_callback).to_proc
    @driver.add_method('miqGetVMs', 'format')
    @driver.add_method('miqSyncMetadata', 'vmName', 'type', 'from_time', 'taskid', 'options')
    @driver.add_method('miqScanMetadata', 'vmName', 'type', 'taskid', 'options')
    @driver.add_method('miqGetHeartBeat', 'vmName')
    @driver.add_method('miqGetVersion')
    @driver.add_method('miqGetVMState', 'vmName')
    @driver.add_method('miqMakeSmart', 'vmName')
    @driver.add_method('miqRegisterId', 'vmName', 'id', 'params')
    @driver.add_method('miqRegisterVM', 'vmName')
    @driver.add_method('miqResetVM', 'vmName', 'guid')
    @driver.add_method('miqSavevmMetadata', 'vmName')
    @driver.add_method('miqStartVM', 'vmName', 'guid')
    @driver.add_method('miqStopVM', 'vmName', 'guid', 'type')
    @driver.add_method('miqSuspendVM', 'vmName', 'guid')
    @driver.add_method('miqPauseVM', 'vmName', 'guid')
    @driver.add_method('miqShutdownGuest', 'vmName', 'guid')
    @driver.add_method('miqStandbyGuest', 'vmName', 'guid')
    @driver.add_method('miqRebootGuest', 'vmName', 'guid')
    @driver.add_method('miqGetHostConfig', 'hostId')
    @driver.add_method('miqSendVMState', 'vmName')
		@driver.add_method('miqScanRepository', 'scanPath', 'repositoryId', 'format')
		@driver.add_method('miqGetEmsInventory', 'emsName')
		@driver.add_method('miqWakeupHeartbeat')
		@driver.add_method('miqGetAgent', 'uri', 'stats')
		@driver.add_method('miqChangeAgentConfig', 'config')
		@driver.add_method('miqActivateAgent', 'uri', 'stats')
		@driver.add_method('miqGetAgentLogs', 'uri', 'options')
		@driver.add_method('miqPolicyCheckVm', 'vmName')
		@driver.add_method('miqReplicateHost', 'installSettings')
		@driver.add_method('miqShutdown', 'data')
    @driver.add_method('miqClearQueueItems', 'data')
    @driver.add_method('miqCreateSnapshot', 'vmName', 'name', 'desc', 'memory', 'quiesce', 'guid')
    @driver.add_method('miqRemoveSnapshot', 'vmName', 'uid_ems', 'guid')
    @driver.add_method('miqRemoveAllSnapshots', 'vmName', 'guid')
    @driver.add_method('miqRevertToSnapshot', 'vmName', 'uid_ems', 'guid')
    @driver.add_method('miqRemoveSnapshotByDescription', 'vmName', 'description', 'guid')
    @driver.add_method('miqPowershellCommand', 'ps_script', 'return_type')
    @driver.add_method('miqPowershellCommandAsync', 'ps_script', 'return_type', 'options')
  end

	def StartVM(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqStartVM(vmName, ost.vm_guid)
	end

	def StopVM(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqStopVM(vmName, ost.vm_guid, nil)
	end

	def GetHeartbeat(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqGetHeartBeat(vmName)
	end

	def GetVMAttributes(ost)
	end

	def GetVMProductInfo(ost)
	end

	def GetVMs(ost)
		fmt = '-f' if ost.fmt
		ost.value = @driver.miqGetVMs(fmt)
	end

	def ScanRepository(ost)
		scanPath = ost.path
		id = ost.repository_id
		fmt = '-f' if ost.fmt
		ost.value = @driver.miqScanRepository(scanPath, id, fmt)
	end
	
	def GetVMState(ost)
    vmName = ost.args[0]
		ost.value = @driver.miqGetVMState(vmName)
	end

	def GetVersion(ost)
    ost.value = @driver.miqGetVersion
	end

	def HasSnapshot(ost)
	end

	def SyncMetadata(ost)
    vmName = ost.args[0]
    options = ost.args[1]
    category = ost.category
    from_time = ost.from_time
    taskid = ost.taskid
    ost.value = @driver.miqSyncMetadata(vmName, category, from_time, taskid, options)
	end

  def ScanMetadata(ost)
    vmName = ost.args[0]
    options = ost.args[1]
    category = ost.category
    taskid = ost.taskid
    ost.value = @driver.miqScanMetadata(vmName, category, taskid, options)
	end

	def ResetVM(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqResetVM(vmName, ost.vm_guid)
	end
  alias reset ResetVM

	def SuspendVM(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqSuspendVM(vmName, ost.vm_guid)
	end

	def PauseVM(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqPauseVM(vmName, ost.vm_guid)
	end

  def shutdownGuest(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqShutdownGuest(vmName, ost.vm_guid)
  end

  def standbyGuest(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqStandbyGuest(vmName, ost.vm_guid)
  end

  def rebootGuest(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqRebootGuest(vmName, ost.vm_guid)
  end

	def RegisterId(ost)
    vmName = ost.args[0]
    if (!ost.vmId)
      ost.error = "ID value not supplied\n"
      ost.show_help = true
      return
    end
    ost.value = @driver.miqRegisterId(vmName, ost.vmId, ost.params)
	end

	def RegisterVM(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqRegisterVM(vmName)
	end

	def SaveVmMetadata(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqSavevmMetadata(vmName)
	end
	
	def MakeSmart(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqMakeSmart(vmName)
	end
  
	def GetHostConfig(ost)
		hostId = nil
		hostId = ost.args[0] if ost.args
		hostId = ost.hostId if ost.hostId
		ost.value = @driver.miqGetHostConfig(hostId)
	end

	def SendVMState(ost)
		vmName = ost.args
		ost.value = @driver.miqSendVMState(vmName)
	end
	
	def GetEmsInventory(ost)
    emsName = ost.args
    ost.value = @driver.miqGetEmsInventory(emsName)
    ost.xml = true
    ost.encode = true
	end
	
	def WakeupHeartbeat(ost)
		@driver.miqWakeupHeartbeat
	end
	
	def GetAgent(ost)
		uri = ost.url
		stats = ost.metadata
		ost.value = @driver.miqGetAgent(uri, stats)
	end
	
	def ChangeAgentConfig(ost)
		ost.value = @driver.miqChangeAgentConfig(ost.config)
	end
	
	def ActivateAgent(ost)
		uri = ost.url
		stats = ost.metadata
		ost.value = @driver.miqActivateAgent(uri, stats)
	end

	def GetAgentLogs(ost)
		ost.value = @driver.miqGetAgentLogs(ost.url, ost.options)
	end
	
	def PolicyCheckVm(ost)
		vmName = ost.args[0]
		ost.code = @driver.miqPolicyCheckVm(vmName)
	end
	
	def ReplicateHost(ost)
		installSettings = ost.args[0]
		ost.value = @driver.miqReplicateHost(installSettings)
	end

	def Shutdown(ost)
		ost.value = @driver.miqShutdown(ost.options)
	end

	def ClearQueueItems(ost)
		ost.value = @driver.miqClearQueueItems(ost.options)
	end

  def vm_create_snapshot(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqCreateSnapshot(vmName, ost.name, ost.desc, ost.memory, ost.quiesce, ost.vm_guid)
  end

  def vm_remove_snapshot(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqRemoveSnapshot(vmName, ost.snMor, ost.vm_guid)
  end

  def vm_remove_all_snapshots(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqRemoveAllSnapshots(vmName, ost.vm_guid)
  end

  def vm_revert_to_snapshot(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqRevertToSnapshot(vmName, ost.snMor, ost.vm_guid)
  end

  def vm_remove_snapshot_by_description(ost)
    vmName = ost.args[0]
    ost.value = @driver.miqRemoveSnapshotByDescription(vmName, ost.description, ost.vm_guid)
  end

  def powershell_command(ost)
    ps_script = ost.args[0]
    return_type = ost.args[1]
    ost.value = @driver.miqPowershellCommand(ps_script, return_type)
  end
  alias PowershellCommand powershell_command

  def powershell_command_async(ost)
    ps_script = ost.args[0]
    return_type = ost.args[1]
    options = ost.args[2]
    ost.value = @driver.miqPowershellCommandAsync(ps_script, return_type, options)
  end

  # Default callback for verification: only dumps error.
  def verify_callback(is_ok, ctx)
    if $DEBUG
      puts "#{is_ok ? 'ok' : 'ng'}: #{ctx.current_cert.subject}"
      STDERR.puts "at depth #{ctx.error_depth} - #{ctx.error}: #{ctx.error_string}" unless is_ok
    end
    is_ok
  end
end
