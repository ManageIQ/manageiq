$:.push("#{File.dirname(__FILE__)}/../../metadata/VmConfig")
$:.push("#{File.dirname(__FILE__)}/../../metadata/MIQExtract")
$:.push("#{File.dirname(__FILE__)}/../../util")

require 'runcmd'
require 'MIQExtract'
require 'VmConfig'
require 'platform'
require 'SharedOps'

class MicrosoftOps
    def initialize(ost)
		extend SharedOps
        case Platform::OS
        when :win32
            require 'MicrosoftOpsWin'
            extend MicrosoftOpsWin
            initializeCOM
        end
    end
	
	def GetVersion(ost)
		return @msCom.hypervisorVersion if @msCom
		nil
	end
	
	def getVmFile(ost)
		vmName = ost.args[0]
    return File.uri_to_local_path(vmName) if vmName[0,7] == "file://"
		return vmName
	end
	
    def diskNames(vmName)
        vmDir = File.dirname(vmName)
	    cfg = VmConfig.new(vmName).getHash
	    dfn = cfg["scsi0:0.filename"]
	    dfn = cfg["ide0:0.filename"] if !dfn
	    raise "Can't determine disk file for virtual machine" if !dfn
		
	    ext = File.extname(dfn)
	    dfBase = File.basename(dfn, ext)
		
	    diskFile = File.join(vmDir, dfBase + ext)
	    diskFileSave = File.join(vmDir, dfBase + ".miq")
	    bbFileSave = File.join(vmDir, dfBase + "BB.miq")
		
        return diskFile, diskFileSave, bbFileSave
    end
	
end # MicrosoftOps
