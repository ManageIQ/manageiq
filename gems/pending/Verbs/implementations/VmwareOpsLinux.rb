require 'util/runcmd'
require 'metadata/MIQExtract/MIQExtract'
require 'metadata/VmConfig/VmConfig'

module VMWareOpsLinux
  def initialize(_ost)
  end

  def StartVM(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    #        diskFile, diskFileSave, bbFileSave = diskNames(vmName)
    #   raise "VM is not smart" if !File.exist?(diskFileSave)

    #
    # The current disk file is the black box, save it before we
    # restore the real disk file.
    #
    #   File.rename(diskFile, bbFileSave) if File.exist?(diskFile)
    #
    # Restore the VM's disk file.
    #
    #   File.rename(diskFileSave, diskFile)

    #
    # Start the VM.
    #
    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" start", ost.test)
  end

  def StopVM(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    diskFile, diskFileSave, bbFileSave = diskNames(vmName)
    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" stop", ost.test)
  end

  def GetHeartbeat(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" getheartbeat", ost.test)
  end

  def GetVMAttributes(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" getproductinfo ???", ost.test)
  end

  def GetVMProductInfo(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" getproductinfo ???", ost.test)
  end

  def GetVMState(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" getstate", ost.test)
  end

  def HasSnapshot(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" hassnapshot", ost.test)
  end

  def ResetVM(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" reset", ost.test)
  end

  def SuspendVM(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" suspend", ost.test)
  end
end
