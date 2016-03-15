require 'ostruct'
require 'blackbox/VmBlackBox'
require 'Verbs/implementations/VmwareOps'
require 'util/diag/miqping'

require 'Verbs/miqservices_client'

class VmdbOps
  def initialize(_ost)
    @vmdbDriver ||= MiqservicesClient.new
  end # def initilaize

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
end # class VmdbOps
