$:.push("#{File.dirname(__FILE__)}/MiqFS")
$:.push("#{File.dirname(__FILE__)}/MetakitFS")
$:.push("#{File.dirname(__FILE__)}/../VolumeManager")

require 'MiqFS'
require 'MiqNativeVolumeManager'
require 'MountManagerProbe'

class MiqMountManager < MiqFS
    
    attr_accessor :rootVolume, :volumes, :guestOS, :fileSystems, :devHash, :osNames, :volMgr, :noFsVolumes, :payloads
    
    def self.mountVolumes(volMgr, vmCfg, ost=nil)
        rootTrees	= Array.new
		noFsVolumes	= Array.new
        volMgr.visibleVolumes.each do |dobj|
			$log.debug("MiqMountManager.mountVolumes >> fileName=#{dobj.dInfo.fileName}, partition=#{dobj.partNum}") if $log
			fs = MiqFS.getFS(dobj)
			if fs.nil?
				$log.debug "MiqMountManager.mountVolumes << SKIPPING because no file system" if $log
				noFsVolumes << dobj
				next
			end
            if (rsm = MountManagerProbe.getRootMod(fs))
                rootTrees << self.new(rsm, dobj, volMgr, vmCfg, ost)
		    end
		end
		if volMgr.kind_of?(MiqNativeVolumeManager)
			require 'MetakitFS'
			rootTrees.each { |rt| rt.findPayload(noFsVolumes) } if !noFsVolumes.empty?
		end
		return rootTrees
    end # def self.mountVolumes
    
    def initialize(rootModule, rootVolume, volMgr, vmCfg, ost=nil)
        @volMgr			= volMgr
        @rootVolume		= rootVolume
        @volumes		= volMgr.visibleVolumes
		@noFsVolumes	= noFsVolumes
        @vmConfig		= vmCfg
        @fileSystems	= []
		@allFileSystems	= []
		@payloads		= []
        @devHash		= nil
		
        super(rootModule, rootVolume)
    end # def initialize

	def findPayload(noFsVolumes)
		$log.debug "MiqMountManager.findPayload: searching for payloads:" if $log
		noFsVolumes.each do |v|
			next if !v.respond_to?(:devFile)
			if v.devFile
				$log.debug "\tMiqMountManager.findPayload: devFile = #{v.devFile}" if $log
				v.mkfile = v.devFile
				if !MetakitFS.supported?(v)
					$log.debug "\tMiqMountManager.findPayload: devFile = #{v.devFile} not mkfs, skipping" if $log
					v.mkfile = nil
					next
				end
				mkFs = MiqFS.new(MetakitFS, v)
				if mkFs.fsId == "MIQPAYLOAD"
					$log.debug "\tMiqMountManager.findPayload: payload found devFile = #{v.devFile}" if $log
					@payloads << mkFs
				else
					$log.debug "\tMiqMountManager.findPayload: devFile = #{v.devFile} not payload, fsId = #{mkFs.fsId}" if $log
				end
			else
				$log.debug "\tMiqMountManager.findPayload: devFile not set, fileName = #{v.dInfo.fileName}" if $log
			end
		end
	end
    
    #
    # Override standard MiqFS methods to account for mount indirection.
    # The getFsPath method is defined by the OS-specific mount modules.
    #

	def umount
		@allFileSystems.each(&:umount)
	end
    
  	# Return free space in file system.
  	def freeBytes
  	    fs, p = getFsPath(@cwd)
  		fs.freeBytes
  	end
	
  	#
  	# Directory instance methods
  	#

  	def dirEntries(*dir)
  	    fs, p = getFsPath(dir)
  	    fs.dirEntries(p)
  	end

  	def dirForeach(*dir, &block)
  	    fs, p = getFsPath(dir)
  	    fs.dirForeach(p, &block)
  	end

  	def dirGlob(glb, *flags, &block)
  	    fs, p = getFsPath(@cwd)
  	    fs.chdir(p)
  	    return fs.dirGlob(glb, &block) if flags.length == 0
  	    fs.dirGlob(glb, flags[0], &block)
  	end
	
  	def dirMkdir(dir)
  	    fs, p = getFsPath(dir)
  	    fs.dirMkdir(p)
  	end
	
  	def dirRmdir(dir)
  	    fs, p = getFsPath(dir)
  	    fs.dirRmdir(p)
  	end

  	#
  	# File instance methods
  	#
	
  	def fileExists?(f)
  	    fs, p = getFsPath(f)
  	    fs.fileExists?(p)
  	end

  	def fileFile?(f)
  	    fs, p = getFsPath(f)
  	    fs.fileFile?(p)
  	end

  	def fileDirectory?(f)
  	    fs, p = getFsPath(f)
  	    fs.fileDirectory?(p)
  	end

    def fileSymLink?(f)
      fs, p = getFsPath(f)
      fs.fileSymLink?(p)
    end

  	def fileOpen(f, mode="r", &block)
  	    fs, p = getFsPath(f)
  	    fs.fileOpen(p, mode, &block)
  	end

  	def fileClose(mfobj)
  	    @mfobj.fs.fileClose(mfobj)
  	end
	
  	def fileDelete(f)
  	    fs, p = getFsPath(f)
  	    fs.fileDelete(p)
  	end

  	def fileSize(f)
  	    fs, p = getFsPath(f)
  	    fs.fileSize(p)
  	end
	
  	def fileAtime(f)
  	    fs, p = getFsPath(f)
  	    fs.fileAtime(p)
  	end
	
  	def fileCtime(f)
  	    fs, p = getFsPath(f)
  	    fs.fileCtime(p)
  	end
	
  	def fileMtime(f)
  	    fs, p = getFsPath(f)
  	    fs.fileMtime(p)
  	end
	
  	def fileAtime_obj(fo)
  	    fo.fs.fileAtime_obj(fo)
  	end
	
  	def fileCtime_obj(fo)
  	    fo.fs.fileCtime_obj(fo)
  	end
	
  	def fileMtime_obj(fo)
  	    fo.fs.fileMtime_obj(fo)
  	end

	def internalPath(p)
		fs, np = getFsPath(p)
  	    fs.internalPath(np)
	end
  	
  	def toXml(doc=nil)
  	    doc = MiqXml.createDoc(nil) if !doc
        
        fses = doc.add_element 'FileSystems'
        @fileSystems.each do |fsd|
            $miqOut.puts "FS: #{fsd.fsSpec}, Mounted on: #{fsd.mountPoint}, Type: #{fsd.fs.fsType}, Free bytes: #{fsd.fs.freeBytes}"
        end
        doc
  	end
    
    private
    
    def saveFs(fs, mp, fsSpec)
  	    fsd = OpenStruct.new
  	    fsd.fs = fs
  	    fsd.mountPoint = mp
  	    fsd.fsSpec = fsSpec
  	    @fileSystems << fsd
  	end
    
end # class MiqMountManager
