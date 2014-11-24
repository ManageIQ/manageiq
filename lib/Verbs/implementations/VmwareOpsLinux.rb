$:.push("#{File.dirname(__FILE__)}/../../metadata/VmConfig")
$:.push("#{File.dirname(__FILE__)}/../../metadata/MIQExtract")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'runcmd'
require 'MIQExtract'
require 'VmConfig'

module VMWareOpsLinux
    def initialize(ost)
    end
    
	def StartVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)

#        diskFile, diskFileSave, bbFileSave = diskNames(vmName)
#		raise "VM is not smart" if !File.exist?(diskFileSave)
			
		#
		# The current disk file is the black box, save it before we
		# restore the real disk file.
		# 
#		File.rename(diskFile, bbFileSave) if File.exist?(diskFile)
		#
		# Restore the VM's disk file.
		# 
#		File.rename(diskFileSave, diskFile)
			
		#
		# Start the VM.
		# 
		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" start", ost.test)

        # Don't worry if the disk rename fails during start
#		begin
#            renameDisks(*diskNames(vmName))    
#        rescue => e
#        end
	end

	def StopVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)

        diskFile, diskFileSave, bbFileSave = diskNames(vmName)
		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" stop", ost.test)
#        sleep(0.5)
#        renameDisks(*diskNames(vmName))
	end

	def GetHeartbeat(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)
		
        ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" getheartbeat", ost.test)
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

		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" getstate", ost.test)
	end

	def HasSnapshot(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)

		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" hassnapshot", ost.test)
	end
  
	def ResetVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)

		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" reset", ost.test)
	end

	def SuspendVM(ost)
		return if !checkArg(ost)
		vmName = getVmFile(ost)

		ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" suspend", ost.test)
#        renameDisks(*diskNames(vmName))
	end
	
end
