$:.push("#{File.dirname(__FILE__)}/../../blackbox")
$:.push("#{File.dirname(__FILE__)}/../../metadata/VmConfig")
$:.push("#{File.dirname(__FILE__)}/../../metadata/MIQExtract")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'runcmd'
require 'MIQExtract'
require 'VmConfig'
require 'VmwareWinCom'
require 'VmBlackBox'

module VMWareOpsWin
	def initializeCOM
		@vmwareCom = VmwareCom.new rescue nil
	end
	
	def StartVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		#diskFile, diskFileSave, bbFileSave = diskNames(vmName)
		#raise "VM is not smart" if !File.exists?(diskFileSave)

		
		#if File.exists?(diskFileSave)
		#
		# The current disk file is the black box, save it before we
		# restore the real disk file.
		# 
		#			File.rename(diskFile, bbFileSave) if File.exists?(diskFile)
		#
		# Restore the VM's disk file.
		# 
		#			File.rename(diskFileSave, diskFile)
		#end
			
		#
		# Start the VM.
		# 
		eventStatus = "failed"
		begin
			if @vmwareCom.start(vmName)
				ost.value = "start() = 1" 

				# Don't worry if the disk rename fails during start
				#		begin
				#			renameDisks(*diskNames(vmName))
				#		rescue => e
				#		end

				eventStatus = "ok"
			end
		ensure
			#record the event to the black box
			Manageiq::BlackBox.recordEvent(vmName, {:event=>"StartVM", :status=>eventStatus} )
		end
	end

	def StopVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
		#diskFile, diskFileSave, bbFileSave = diskNames(vmName)
		
		eventStatus = "failed"
		begin
			if @vmwareCom.stop(vmName)
				ost.value = "stop() = 1" 

				#		renameDisks(*diskNames(vmName)) if isSmart?(vmName)

				eventStatus = "ok"
			end
		ensure
			#record the event to the black box
			Manageiq::BlackBox.recordEvent(vmName, {:event=>"StopVM", :status=>eventStatus} )
		end
	end

	def GetHeartbeat(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		ost.value = "getheartbeat() = " + @vmwareCom.heartbeat(vmName).to_s
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
			ost.value = "getstate() = " + @vmwareCom.state(vmName)
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

		eventStatus = "failed"
		begin
			if @vmwareCom.reset(vmName)
				ost.value = "reset() = 1"		 
				eventStatus = "ok"
			end
		ensure 
			#record the event to the black box
			Manageiq::BlackBox.recordEvent(vmName, {:event=>"ResetVM", :status=>eventStatus} )
    end
	end

	def SuspendVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)

		eventStatus = "failed"
		begin
			if @vmwareCom.suspend(vmName)
				ost.value = "suspend() = 1" 
				
				#		renameDisks(*diskNames(vmName)) if isSmart?(vmName)
				
				eventStatus = "ok"
			end
		ensure
			#record the event to the black box
			Manageiq::BlackBox.recordEvent(vmName, {:event=>"SuspendVM", :status=>eventStatus} )
		end
	end

end # module VmwareOpsWin
