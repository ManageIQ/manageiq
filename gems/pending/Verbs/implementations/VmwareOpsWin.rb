require 'util/runcmd'
require 'metadata/MIQExtract/MIQExtract'
require 'metadata/VmConfig/VmConfig'
require 'Verbs/implementations/VmwareWinCom'

module VMWareOpsWin
  def initializeCOM
    @vmwareCom = VmwareCom.new rescue nil
  end

  def StartVM(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    # diskFile, diskFileSave, bbFileSave = diskNames(vmName)
    # raise "VM is not smart" if !File.exist?(diskFileSave)

    # if File.exist?(diskFileSave)
    #
    # The current disk file is the black box, save it before we
    # restore the real disk file.
    #
    #     File.rename(diskFile, bbFileSave) if File.exist?(diskFile)
    #
    # Restore the VM's disk file.
    #
    #     File.rename(diskFileSave, diskFile)
    # end

    #
    # Start the VM.
    #
    eventStatus = "failed"
    begin
      if @vmwareCom.start(vmName)
        ost.value = "start() = 1"
        eventStatus = "ok"
      end
    end
  end

  def StopVM(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    # diskFile, diskFileSave, bbFileSave = diskNames(vmName)

    eventStatus = "failed"
    begin
      if @vmwareCom.stop(vmName)
        ost.value = "stop() = 1"
        eventStatus = "ok"
      end
    end
  end

  def GetHeartbeat(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)
    ost.value = "getheartbeat() = " + @vmwareCom.heartbeat(vmName).to_s
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
    begin
      ost.value = "getstate() = " + @vmwareCom.state(vmName)
    rescue
      ost.value = "getstate() = unknown"
    end
  end

  def HasSnapshot(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    ost.value = MiqUtil.runcmd("vmware-cmd \"#{vmName}\" hassnapshot", ost.test)
  end

  def ResetVM(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    eventStatus = "failed"
    begin
      if @vmwareCom.reset(vmName)
        ost.value = "reset() = 1"
        eventStatus = "ok"
      end
    end
  end

  def SuspendVM(ost)
    return unless checkArg(ost)
    vmName = getVmFile(ost)

    eventStatus = "failed"
    begin
      if @vmwareCom.suspend(vmName)
        ost.value = "suspend() = 1"
        eventStatus = "ok"
      end
    end
  end
end # module VmwareOpsWin
