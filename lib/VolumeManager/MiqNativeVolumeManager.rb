$:.push("#{File.dirname(__FILE__)}/../disk")
$:.push("#{File.dirname(__FILE__)}/../util")

require "ostruct"
require "MiqDisk"
require 'binary_struct'
require 'MiqLvm'

class MiqNativeVolumeManager
    
    attr_accessor :rootTrees
    attr_reader :logicalVolumes, :physicalVolumes, :visibleVolumes, :hiddenVolumes, :allPhysicalVolumes, :vgHash, :wholeDisks, :diskInitErrors
    
    def initialize(vmCfg, ost=nil)
        @logicalVolumes     = Array.new         # visible logical volumes
        @physicalVolumes    = Array.new         # visible physical volumes
        @hiddenVolumes      = Array.new         # hidded volumes (in volume groups)
        @allPhysicalVolumes = Array.new         # all physical volumes
        @wholeDisks         = Array.new         # a list of open base disks
		@visibleVolumes		= nil				# logical and physical volumes that should eb checked for filesystems
        @vgHash             = Hash.new          # volume groups hashed by name
		@lvHash             = Hash.new
        @rootTrees          = nil               # the MiqMountManager objects using this MiqVolumeManager object
        
        @diskFileNames = vmCfg.getDiskFileHash

		`vgdisplay -c 2> /dev/null`.each { |vgl| vg = getVg(vgl); @vgHash[vg.vgName] = vg }
		`lvdisplay -c 2> /dev/null`.each { |lvl| lv = getLv(lvl); @lvHash[lv.lvPath] = lv }

		vgNames			= @vgHash.keys
		lvNames			= @lvHash.keys
		hiddenDevNames	= `pvdisplay -c 2> /dev/null`.split("\n").collect! { |p| p.lstrip.split(":", 2)[0] }
		
		if $log.debug?
			$log.debug "\nVolume Groups: (#{vgNames.class}: #{vgNames.length})"
			vgNames.each { |dn| $log.debug "\t#{dn}"}
			$log.debug "\nLogical Volumes: (#{lvNames.class}: #{lvNames.length})"
			lvNames.each { |dn| $log.debug "\t#{dn}"}
			$log.debug "\nHidden devs: (#{hiddenDevNames.class}: #{hiddenDevNames.length})"
		end
        
        physVolumes = openPhysicalVolumes(@diskFileNames)

		$log.debug "\nMiqNativeVolumeManager: physVolumes:" if $log.debug?
		physVolumes.each do |pv|
			if $log.debug?
				$log.debug "\t#{pv.devFile} => #{pv.dInfo.hardwareId} (SIG: #{pv.dInfo.diskSig})"
				$log.debug "\t\tPartition: #{pv.partNum}, Type: #{pv.partType}"
			end
			if hiddenDevNames.include?(pv.devFile)
				$log.debug "\t\t\tHIDDEN VOLUME" if $log.debug?
				hiddenVolumes << pv
			else
				@physicalVolumes << pv
			end
			@allPhysicalVolumes << pv
		end
		
		vgNames.each { |vgn| `vgchange -a y #{vgn}` }
		
		@logicalVolumes = openLogicalVolumes(lvNames)
		@visibleVolumes = @logicalVolumes + @physicalVolumes
    end
    
    def closeAll
        @wholeDisks.each(&:close)
        @logicalVolumes     = Array.new
        @physicalVolumes    = Array.new
        @hiddenVolumes      = Array.new
        @wholeDisks         = Array.new
        @vgHash             = nil
        @ost.miqVim.closeVdlConnection(@vdlConnection) if @vdlConnection
        @volMgrPS.postMount
    end
    
    def openLogicalVolumes(lvnames)
        lvList = Array.new
        lvnames.each do |lvn|
            #
            # get MiqDisk object for each LV and add to lvList.
            #
            dInfo = OpenStruct.new
            dInfo.localDev = lvn
			dInfo.lvObj = @lvHash[lvn]
            dInfo.hardwareId = ""
            lvList << MiqDisk.getDisk(dInfo)
        end
        return lvList
    end # def openLogicalVolumes
    
    def openPhysicalVolumes(diskFiles)
        pVolumes = Array.new
        
        $log.debug "openPhysicalVolumes: no disk files supplied." if !diskFiles
        
        #
        # Build a list of the VM's physical volumes.
        #
        diskFiles.each do |dtag, df|
            $log.debug "openPhysicalVolumes: processing disk file (#{dtag}): #{df}"
            dInfo = OpenStruct.new
            dInfo.localDev = df
            dInfo.hardwareId = dtag
            
            begin
                d = MiqDisk.getDisk(dInfo)
                # I am not sure if getting a nil handle back should throw an error or not.
                # For now I am just skipping to the next disk.  (GMM)
                next if d.nil?
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
    end # def openPhysicalVolumes

	def getVg(vgl)
		vga = vgl.lstrip.split(":")
		return(VolumeGroup.new(vga[16], vga[0]))
	end
	
	def getLv(lvl)
		lva = lvl.lstrip.split(":")
		lvPath = lva[0]
		vgName = lva[1]
		lvId   = `lvdisplay -v #{lvPath} 2> /dev/null | grep "LV UUID"`.split(" ").last
		lv  = LogicalVolume.new(lvId, File.basename(lvPath))
		
		vg = @vgHash[vgName]
		lv.vgObj	= vg
		lv.lvPath	= lvPath
		vg.logicalVolumes[lv.lvName] = lv
	end
    
end # class MiqNativeVolumeManager
