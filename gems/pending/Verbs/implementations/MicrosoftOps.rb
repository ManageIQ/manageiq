require 'util/runcmd'
require 'metadata/MIQExtract/MIQExtract'
require 'metadata/VmConfig/VmConfig'
require 'sys-uname'
require 'Verbs/implementations/SharedOps'

class MicrosoftOps
  def initialize(_ost)
    extend SharedOps
    case Sys::Platform::OS
    when :windows
      require 'MicrosoftOpsWin'
      extend MicrosoftOpsWin
      initializeCOM
    end
  end

  def GetVersion(_ost)
    return @msCom.hypervisorVersion if @msCom
    nil
  end

  def getVmFile(ost)
    vmName = ost.args[0]
    return File.uri_to_local_path(vmName) if vmName[0, 7] == "file://"
    vmName
  end

  def diskNames(vmName)
    vmDir = File.dirname(vmName)
    cfg = VmConfig.new(vmName).getHash
    dfn = cfg["scsi0:0.filename"]
    dfn = cfg["ide0:0.filename"] unless dfn
    raise "Can't determine disk file for virtual machine" unless dfn

    ext = File.extname(dfn)
    dfBase = File.basename(dfn, ext)

    diskFile = File.join(vmDir, dfBase + ext)
    diskFileSave = File.join(vmDir, dfBase + ".miq")
    bbFileSave = File.join(vmDir, dfBase + "BB.miq")

    return diskFile, diskFileSave, bbFileSave
  end
end # MicrosoftOps
