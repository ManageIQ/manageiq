$:.push("#{File.dirname(__FILE__)}/../../metadata/VmConfig")
$:.push("#{File.dirname(__FILE__)}/../../metadata/MIQExtract")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'runcmd'
require 'MIQExtract'
require 'VmConfig'
require 'MicrosoftWinCom'

module MicrosoftOpsWin
  def initializeCOM
		@msCom = MSVirtualServerCom.new rescue nil
  end
	
	def StartVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		diskFile, diskFileSave, bbFileSave = diskNames(vmName)
		#raise "VM is not smart" if !File.exists?(diskFileSave)
		
		
		if File.exists?(diskFileSave)
			#
			# The current disk file is the black box, save it before we
			# restore the real disk file.
			# 
			#			File.rename(diskFile, bbFileSave) if File.exists?(diskFile)
			#
			# Restore the VM's disk file.
			# 
			#			File.rename(diskFileSave, diskFile)
		end
		
		#
		# Start the VM.
		# 
		ost.value = "start() = 1" if @msCom.start(vmName)
		
		# Don't worry if the disk rename fails during start
		#		begin
		#			renameDisks(*diskNames(vmName))
		#		rescue => e
		#		end
	end
	
	def StopVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		diskFile, diskFileSave, bbFileSave = diskNames(vmName)
		ost.value = "stop() = 1" if @msCom.stop(vmName)
		
		#		renameDisks(*diskNames(vmName)) if isSmart?(vmName)
	end
	
	def GetHeartbeat(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		ost.value = "getheartbeat() = " + @msCom.heartbeat(vmName).to_s
	end
	
	def GetVMAttributes(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" getproductinfo ???", ost.test)
	end
	
	def GetVMProductInfo(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" getproductinfo ???", ost.test)
	end
	
	def GetVMState(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		begin
			ost.value = "getstate() = " + @msCom.state(vmName)
		rescue
			ost.value = "getstate() = unknown"
		end
	end
	
	def HasSnapshot(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" hassnapshot", ost.test)
	end
	
	def ResetVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		ost.value = "reset() = 1" if @msCom.reset(vmName)
	end
	
	def SuspendVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		ost.value = "suspend() = 1" if @msCom.suspend(vmName)
		#		renameDisks(*diskNames(vmName)) if isSmart?(vmName)
	end

	def PauseVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)

		ost.value = "pause() = 1" if @msCom.pause(vmName)
		#		renameDisks(*diskNames(vmName)) if isSmart?(vmName)
	end

	def ShutdownGuest(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		ost.value = "shutdownGuest() = 1" if @msCom.shutdownGuest(vmName)
	end

	def StandbyGuest(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		ost.value = "standbyGuest() = 1" if @msCom.standbyGuest(vmName)
	end

	def RebootGuest(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		ost.value = "rebootGuest() = 1" if @msCom.rebootGuest(vmName)
	end

	def CreateSnapshot(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		ost.value = "create_snapshot() = 1" if @msCom.create_snapshot(vmName, ost.name, ost.description)
	end

  def RemoveSnapshot(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
    sn_uid = ost.args[1]
		ost.value = "remove_snapshot() = 1" if @msCom.remove_snapshot(vmName, sn_uid)
  end

  def RemoveAllSnapshots(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		ost.value = "remove_all_snapshots() = 1" if @msCom.remove_all_snapshots(vmName)
  end

  def RevertToSnapshot(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
    sn_uid = ost.args[1]
		ost.value = "revert_to_snapshot() = 1" if @msCom.revert_to_snapshot(vmName, sn_uid)
  end

  def RemoveSnapshotByDescription(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
    description = ost.args[1]
		ost.value = "remove_snapshot_by_description() = 1" if @msCom.remove_snapshot_by_description(vmName, description)
  end
end # module MicrosoftOpsWin
