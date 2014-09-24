$:.push("#{File.dirname(__FILE__)}/../metadata/VmConfig")
$:.push("#{File.dirname(__FILE__)}/../metadata/MIQExtract")
$:.push("#{File.dirname(__FILE__)}/../disk")
$:.push("#{File.dirname(__FILE__)}/../fs")
$:.push("#{File.dirname(__FILE__)}/../VolumeManager")

require 'ostruct'
require 'VmConfig'
require 'MiqDisk'
# require 'MiqFS'
require 'MiqVolumeManager'
require 'MiqMountManager'
require 'MIQExtract'

class MiqVm
    
    attr_reader :vmConfig, :vmConfigFile, :vim, :vimVm, :rhevm, :rhevmVm, :diskInitErrors, :wholeDisks
    
    def initialize(vmCfg, ost=nil)
        @ost = ost || OpenStruct.new
        $log.debug "MiqVm::initialize: @ost = nil" if $log && !@ost
        @vmDisks = nil
        @wholeDisks = []
        @vmRootTrees = nil
        @volumeManager = nil
        @applianceVolumeManager = nil
        @vmConfigFile = ""
        @diskInitErrors = {}
        unless vmCfg.kind_of?(Hash)
            @vmConfigFile = vmCfg
            @vmDir = File.dirname(vmCfg)
        end

        $log.debug "MiqVm::initialize: @ost.openParent = #{@ost.openParent}" if $log
        
        #
        # If we're passed an MiqVim object, then use VIM to obtain the Vm's
        # configuration through the instantiated server.
        # If we're passed a snapshot ID, then obtain the configration of the
        # VM when the snapshot was taken.
        #
        if (@vim = @ost.miqVim)
            $log.debug "MiqVm::initialize: accessing VM through server: #{@vim.server}" if $log.debug?
            @vimVm = @vim.getVimVm(vmCfg)
            $log.debug "MiqVm::initialize: setting @ost.miqVimVm = #{@vimVm.class.to_s}" if $log.debug?
            @ost.miqVimVm = @vimVm
            @vmConfig = VmConfig.new(@vimVm.getCfg(@ost.snapId))
        elsif (@rhevm = @ost.miqRhevm)
            $log.debug "MiqVm::initialize: accessing VM through RHEVM server" if $log.debug?
            @rhevmVm = @rhevm.getRhevmVm(vmCfg)
            $log.debug "MiqVm::initialize: setting @ost.miqRhevmVm = #{@rhevmVm.class.to_s}" if $log.debug?
            @ost.miqRhevmVm = @rhevmVm
            @vmConfig = VmConfig.new(@rhevmVm.getCfg(@ost.snapId))
        else
            @vimVm = nil
            @vmConfig = VmConfig.new(vmCfg)
        end
    end # def initialize
    
    def vmDisks
        @vmDisks ||= begin
            @volMgrPS = VolMgrPlatformSupport.new(@vmConfig.configFile, @ost)
            @volMgrPS.preMount

            openDisks(@vmConfig.getDiskFileHash)
        end
    end

    def openDisks(diskFiles)        
        pVolumes = Array.new
        
        $log.debug "openDisks: no disk files supplied." if !diskFiles
        
        #
        # Build a list of the VM's physical volumes.
        #
        diskFiles.each do |dtag, df|
            $log.debug "openDisks: processing disk file (#{dtag}): #{df}"
            dInfo = OpenStruct.new
            
            if @ost.miqVim
                dInfo.vixDiskInfo = Hash.new
                if @ost.miqVimVm && @ost.miqVim.isVirtualCenter?
                    @vdlConnection = @ost.miqVimVm.vdlVcConnection if !@vdlConnection
                    dInfo.vixDiskInfo[:fileName]    = @ost.miqVim.datastorePath(df)
                    $log.debug "openDisks (VC): using disk file path: #{dInfo.vixDiskInfo[:fileName]}"
                else
                    @vdlConnection = @ost.miqVim.vdlConnection if !@vdlConnection
                    dInfo.vixDiskInfo[:fileName]    = @ost.miqVim.localVmPath(df)
                    $log.debug "openDisks (ESX): using disk file path: #{dInfo.vixDiskInfo[:fileName]}"
                end
                dInfo.vixDiskInfo[:connection]  = @vdlConnection
            else
                dInfo.fileName = df
                disk_format = @vmConfig.getHash["#{dtag}.format"]  # Set by rhevm for iscsi and fcp disks
                dInfo.format = disk_format unless disk_format.blank?
            end

            mode = @vmConfig.getHash["#{dtag}.mode"]
            
            dInfo.hardwareId = dtag
            dInfo.baseOnly = @ost.openParent unless mode && mode["independent"]
            dInfo.rawDisk = @ost.rawDisk # force raw disk for testing
            $log.debug "MiqVolumeManager::openDisks: dInfo.baseOnly = #{dInfo.baseOnly}"
            
            begin
                d = applianceVolumeManager.lvHash[dInfo.fileName] if @rhevm
                if d
                    $log.debug "MiqVolumeManager::openDisks: using applianceVolumeManager for #{dInfo.fileName}" if $log.debug?
                    d.dInfo.fileName = dInfo.fileName
                    d.dInfo.hardwareId = dInfo.hardwareId
                    d.dInfo.baseOnly = dInfo.baseOnly
                    d.dInfo.format = dInfo.format if dInfo.format
                    d.dInfo.applianceVolumeManager = applianceVolumeManager
                    #
                    # Here, we need to probe the disk to determine its data format,
                    # QCOW for example. If the disk format is not flat, push a disk
                    # supporting the format on top of this disk. Then set d to point
                    # to the new top disk.
                    #
                    d = d.pushFormatSupport
                else
                    d = MiqDisk.getDisk(dInfo)
                    # I am not sure if getting a nil handle back should throw an error or not.
                    # For now I am just skipping to the next disk.  (GMM)
                    next if d.nil?
                    
                    #
                    # If this is the BlackBox disk, skip it.
                    #
                    if Manageiq::BlackBox.isBlackBox?(d)
                        d.close
                        next
                    end
                end
            rescue => err
                $log.error "Couldn't open disk file: #{df}"
                $log.error err.to_s
                $log.debug err.backtrace.join("\n")
                @diskInitErrors[df] = err.to_s
                next
            end
            
            @wholeDisks << d
            p = d.getPartitions 
            if p.empty?
                #
                # If the disk has no partitions, the whole disk can be a single volume.
                #
                pVolumes << d
            else
                #
                # If the disk is partitioned, the partitions are physical volumes,
                # but not the whild disk.
                #
                pVolumes.concat(p)
            end
        end
        
        return pVolumes
    end # def openDisks
    
    def vmRootTrees
        return @vmRootTrees if @vmRootTrees
        @vmRootTrees = MiqMountManager.mountVolumes(volumeManager, @vmConfig, @ost)
        volumeManager.rootTrees = @vmRootTrees
        return @vmRootTrees
    end
    
    def volumeManager
        @volumeManager ||= MiqVolumeManager.new(vmDisks)
    end

    def applianceVolumeManager
        @applianceVolumeManager ||= MiqVolumeManager.fromNativePvs
    end

    def snapshots(refresh=false)
      return nil unless @vimVm
      return @vimVm.snapshotInfo(refresh) if @vimVm
    end
    
    def unmount
		$log.info "MiqVm.unmount called."
        @wholeDisks.each { |d| d.close }
        @wholeDisks.clear
        if @volumeManager
            @volumeManager.close
            @volumeManager = nil
        end
        @applianceVolumeManager.closeAll if @applianceVolumeManager
        @applianceVolumeManager = nil
        @ost.miqVim.closeVdlConnection(@vdlConnection) if @vdlConnection
        if @volMgrPS
            @volMgrPS.postMount
            @volMgrPS = nil
        end
        @vimVm.release if @vimVm
        @vmRootTrees = nil
        @vmDisks = nil
    end

    def miq_extract
        @miq_extract ||= MIQExtract.new(self, @ost)
    end
    
    def extract(c)
        xml = miq_extract.extract(c)
        raise "Could not extract \"#{c}\" from VM" if !xml
        return(xml)
    end
    
end # class MiqVm

if __FILE__ == $0
    $:.push("#{File.dirname(__FILE__)}/../metadata/util/win32")
    
    require 'rubygems'
    require 'log4r'
    require 'boot_info_win'
    
    # vmDir = File.join(ENV.fetch("HOME", '.'), 'VMs')
	vmDir = "/volumes/WDpassport/Virtual Machines"
    puts "vmDir = #{vmDir}"
    
    targetLv = "rpolv2"
    rootLv = "LogVol00"
    
    class ConsoleFormatter < Log4r::Formatter
    	def format(event)
    		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
    	end
    end

    toplog = Log4r::Logger.new 'toplog'
    Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
    toplog.add 'err_console'
    $log = toplog if $log.nil?
    
    #
    # *** Test start
    #
    
    # vmCfg = File.join(vmDir, "cacheguard/cacheguard.vmx")
    # vmCfg = File.join(vmDir, "Red Hat Linux.vmwarevm/Red Hat Linux.vmx")
    # vmCfg = File.join(vmDir, "MIQ Server Appliance - Ubuntu MD - small/MIQ Server Appliance - Ubuntu.vmx")
    # vmCfg = File.join(vmDir, "winxpDev.vmwarevm/winxpDev.vmx")
	vmCfg = File.join(vmDir, "Win2K_persistent/Windows 2000 Professional.vmx")
	# vmCfg = File.join(vmDir, "Win2K_non_persistent/Windows 2000 Professional.vmx")
    puts "VM config file: #{vmCfg}"

	ost = OpenStruct.new
	ost.openParent = true
    
    vm = MiqVm.new(vmCfg, ost)
    
    puts "\n*** Disk Files:"
    vm.vmConfig.getDiskFileHash.each do |k, v|
        puts "\t#{k}\t#{v}"
    end

	puts "\n*** configHash:"
	vm.vmConfig.getHash.each do |k, v|
		puts "\t#{k} => #{v}"
	end
    
    tlv = nil
    rlv = nil
    puts "\n*** Visible Volumes:"
    vm.volumeManager.visibleVolumes.each do |vv|
        puts "\tDisk type: #{vv.diskType}"
        puts "\tDisk sig: #{vv.diskSig}"
        puts "\tStart LBA: #{vv.lbaStart}"
        if vv.respond_to?(:logicalVolume)
            puts "\t\tLV name: #{vv.logicalVolume.lvName}"
            puts "\t\tLV UUID: #{vv.logicalVolume.lvId}"
            tlv = vv if vv.logicalVolume.lvName == targetLv
            rlv = vv if vv.logicalVolume.lvName == rootLv
        end
    end
     
   # raise "#{targetLv} not found" if !tlv
   # 
   # tlv.seek(0, IO::SEEK_SET)
   # rs = tlv.read(2040)
   # puts "\n***** START *****"
   # puts rs
   # puts "****** END ******"
   # 
   # tlv.seek(2048*512*5119, IO::SEEK_SET)
   # rs = tlv.read(2040)
   # puts "\n***** START *****"
   # puts rs
   # puts "****** END ******"
   # 
   # raise "#{rootLv} not found" if !rlv
   # 
   # puts "\n*** Mounting #{rootLv}"
   # rfs = MiqFS.getFS(rlv)
   # puts "\tFS Type: #{rfs.fsType}"
   # puts "\t*** Root-level files and directories:"
   # rfs.dirForeach("/") { |de| puts "\t\t#{de}" }
    
    puts "\n***** Detected Guest OSs:"
    raise "No OSs detected" if vm.vmRootTrees.length == 0
    vm.vmRootTrees.each do |rt|
        puts "\t#{rt.guestOS}"
        if rt.guestOS == "Linux"
            puts "\n\t\t*** /etc/fstab contents:"
            rt.fileOpen("/etc/fstab") { |fo| fo.read }.each_line do |fstl|
                next if fstl =~ /^#.*$/
                puts "\t\t\t#{fstl}"
            end
        end
    end
    
    vm.vmRootTrees.each do |rt|
        if rt.guestOS == "Linux"
            # tdirArr = [ "/", "/boot", "/var/www/miq", "/var/www/miq/vmdb/log", "/var/lib/mysql" ]
            tdirArr = [ "/", "/boot", "/etc/init.d", "/etc/rc.d/init.d", "/etc/rc.d/rc0.d" ]
    
            tdirArr.each do |tdir|
                begin
                    puts "\n*** Listing #{tdir} directory (1):"
                    rt.dirForeach(tdir) { |de| puts "\t\t#{de}" }
                    puts "*** end"
    
                    puts "\n*** Listing #{tdir} directory (2):"
                    rt.chdir(tdir)
                    rt.dirForeach { |de| puts "\t\t#{de}" }
                    puts "*** end"
                rescue => err
                    puts "*** #{err}"
                end
            end
            
            # lf = rt.fileOpen("/etc/rc0.d/S01halt")
            # puts "\n*** Contents of /etc/rc0.d/S01halt:"
            # puts lf.read
            # puts "*** END"
            # lf.close
            # 
            # lfn = "/etc/rc0.d/S01halt"
            # puts "Is #{lfn} a symbolic link? #{rt.fileSymLink?(lfn)}"
            # puts "#{lfn} => #{rt.getLinkPath(lfn)}"
        else  # Windows
            tdirArr = [ "c:/", "e:/", "e:/testE2", "f:/" ]

            tdirArr.each do |tdir|
                puts "\n*** Listing #{tdir} directory (1):"
                rt.dirForeach(tdir) { |de| puts "\t\t#{de}" }
                puts "*** end"

                puts "\n*** Listing #{tdir} directory (2):"
                rt.chdir(tdir)
                rt.dirForeach { |de| puts "\t\t#{de}" }
                puts "*** end"
            end
        end
    end
    
    vm.unmount
    puts "...done"
end
