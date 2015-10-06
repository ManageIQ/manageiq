require 'util/runcmd'
require 'metadata/MIQExtract/MIQExtract'
require 'metadata/VmConfig/VmConfig'
require 'sys-uname'
require 'Verbs/implementations/SharedOps'
require 'VMwareWebService/MiqVimInventory'
require 'util/miq-password'

class VMWareOps
  def initialize(_ost)
    extend SharedOps
    case Sys::Platform::OS
    when :windows
      require 'Verbs/implementations/VmwareOpsWin'
      extend VMWareOpsWin
      initializeCOM
    when :unix
      require 'Verbs/implementations/VmwareOpsLinux'
      extend VMWareOpsLinux
    else
      raise "Unsupported platform: #{Sys::Platform::OS}-#{Sys::Platform::IMPL}"
    end
  end

  def ScanRepository(ost)
    rPath = ost.args[0]
    # Normalize scan path
    $log.debug "ScanRepository: path = #{rPath}"
    rPath.tr!("\\", "/")

    vi = nil
    if MiqVimInventory.dsPath?(rPath)
      raise "ScanRepository: cannot scan datastore path #{rPath}, emsLocal is not set" if !$miqHostCfg || !$miqHostCfg.emsLocal

      ems = $miqHostCfg.ems[$miqHostCfg.emsLocal]
      $log.debug "ScanRepository: emsHost = #{ems['host']}, emsUser = #{ems['user']}, emsPassword = #{ems['password']}" if $log
      vi = MiqVimInventory.new(ems['host'], ems['user'], MiqPassword.decrypt(ems['password']))

      scanPath = vi.localVmPath(rPath)
      dsName = MiqVimInventory.path2dsName(rPath)
    else
      scanPath = rPath
    end
    $log.debug "ScanRepository: converted path = #{scanPath}"

    # This will throw an error if the directory cannot be opened.
    Dir.open(scanPath).close
    ra = []
    total_found = 0
    scanPath = File.join(scanPath, "/**/*.{vmx,vmtx,vmc,xen3.cfg,xml}")
    $log.info "ScanRepository: Starting scan for [#{scanPath}]"
    Dir.glob(scanPath).each do |l|
      begin
        total_found += 1
        $log.debug "ScanRepository: found VM config file = #{l}"
        ra.push(formatVmHash(l, :registeredOnHost => false, :repository_id => ost.args[1]))
      rescue => e
        $log.debug "ScanRepository: Unable to process VM configuration file [#{l}].  Message:[#{e}]"
      end
    end

    $log.info "ScanRepository: Scan [#{scanPath}] return [#{ra.length}] VMs out of [#{total_found}] matching files."

    ra.each do |vh|
      #
      # Convert the local path of each VM found, to it's datastore path.
      #
      $log.debug "ScanRepository: local location = #{vh[:location]}"
      vh[:location][vi.dsName2path(dsName)] = "[#{dsName}] "
      $log.debug "ScanRepository: datastore location = #{vh[:location]}"
    end if vi

    vi.disconnect if vi

    ost.value = formatVmList(ra, ost)
    $log.debug "ScanRepository returning: #{ost.value}"
  end

  def GetVersion(ost)
    ost.value = MiqUtil.runcmd("vmware -v", ost.test)
  end

  def self.isVmwareFile?(arg)
    if arg.kind_of? String
      file = arg
    else
      file = arg.args[0]
    end

    return true if File.extname(file) == ".vmx"
    false
  end

  def self.getVmFile(ost)
    vmName = ost.args[0]

    return File.uri_to_local_path(vmName) if !$miqHostCfg || !$miqHostCfg.emsLocal

    #
    # TODO: We should try to cache the inventory information to make this faster.
    #
    $log.debug "getVmFile: vmName = #{vmName}" if $log
    return File.uri_to_local_path(vmName) unless MiqVimInventory.dsPath?(vmName)

    ems = $miqHostCfg.ems[$miqHostCfg.emsLocal]
    $log.debug "getVmFile: emsHost = #{ems['host']}, emsUser = #{ems['user']}, emsPassword = #{ems['password']}" if $log
    vi = MiqVimInventory.new(ems['host'], ems['user'], MiqPassword.decrypt(ems['password']))

    lp = vi.localVmPath(vmName)
    $log.debug "getVmFile: localPath = #{lp}" if $log
    vi.disconnect
    lp
  end

  def getVmFile(ost)
    VMWareOps.getVmFile(ost)
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
end
