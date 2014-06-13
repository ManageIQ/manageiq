$:.push("#{File.dirname(__FILE__)}/../MiqFS")

require 'MiqFS'

module LinuxMount
        
    FSTAB_FILE_NAME = "/etc/fstab"
    
    def fs_init
        @guestOS = "Linux"
        
        @rootFS = MiqFS.getFS(@rootVolume)
        raise "LinuxMount: could not mount root volume" if !@rootFS
        
        saveFs(@rootFS, "/", "ROOT")
                
        #
        # Assign device letters to all ide and scsi devices,
        # even if they're not visible volumes. We need to do
        # this to assign the proper device names to visible
        # devices.
        #
        sdLetter	= 'a'
		ideMap		= { "ide0:0" => "a", "ide0:1" => "b", "ide1:0" => "c", "ide1:1" => "d" }
        @devHash = Hash.new
        @vmConfig.getAllDiskKeys.each do |dk|
            if dk =~ /^ide.*$/
                @devHash[dk] = "/dev/hd" + ideMap[dk]
				$log.debug "LinuxMount: devHash[#{dk}] = /dev/hd#{ideMap[dk]}" if $log.debug?
            elsif dk =~ /^scsi.*$/
                @devHash[dk] = "/dev/sd" + sdLetter
				$log.debug "LinuxMount: devHash[#{dk}] = /dev/sd#{sdLetter}" if $log.debug?
                sdLetter.succ!
            end
        end
        
        #
        # Build hash for fstab fs_spec look up.
        #
        fsSpecHash = Hash.new
        @volumes.each do |v|
			$log.debug "LinuxMount: Volume = #{v.dInfo.localDev} (#{v.dInfo.hardwareId}, partition = #{v.partNum})" if $log.debug?
            if v == @rootVolume
                fs = @rootFS
            else
                if !(fs = MiqFS.getFS(v))
					$log.debug "LinuxMount: No filesystem on Volume: #{v.dInfo.localDev}, partition = #{v.partNum}" if $log.debug?
					next
				end
            end
			@allFileSystems << fs
            
            #
            # Specific file systems can be identified by fs UUID
            # or file system volume label.
            #
			if !fs.volName.empty?
				$log.debug "LinuxMount: adding \"LABEL=#{fs.volName}\" to fsSpecHash" if $log.debug?
	            fsSpecHash["LABEL=#{fs.volName}"]  = fs
				$log.debug "LinuxMount: adding \"LABEL=/#{fs.volName}\" to fsSpecHash" if $log.debug?
				fsSpecHash["LABEL=/#{fs.volName}"] = fs
			end
			if !fs.fsId.empty?
				$log.debug "LinuxMount: adding \"UUID=#{fs.fsId}\" to fsSpecHash" if $log.debug?
	            fsSpecHash["UUID=#{fs.fsId}"] = fs
			end
            
            #
            # Logical volumes can be identified by their lv specific
            # entries under /dev.
            #
            if v.dInfo.lvObj
                lvName = v.dInfo.lvObj.lvName
                vgName = v.dInfo.lvObj.vgObj.vgName
                fsSpecHash["/dev/#{vgName}/#{lvName}"] = fs
                fsSpecHash["/dev/mapper/#{vgName}-#{lvName}"] = fs
                fsSpecHash["UUID=#{v.dInfo.lvObj.lvId}"] = fs
				$log.debug "LinuxMount: Volume = #{v.dInfo.localDev}, partition = #{v.partNum} is a logical volume" if $log.debug?
                next
            end
            
            #
            # Physical volumes are identified by entries under
            # /dev based on OS hardware scan.
            # TODO: support physical volume UUIDs
            #
			$log.debug "LinuxMount: v.dInfo.hardwareId = #{v.dInfo.hardwareId}" if $log.debug?
            if v.partNum == 0
                fsSpecHash[@devHash[v.dInfo.hardwareId]] = fs
            else
                fsSpecHash[@devHash[v.dInfo.hardwareId] + v.partNum.to_s] = fs
            end
        end
        
        #
        # Assign OS-specific names to all physical volumes.
        #
        @osNames = Hash.new
        @volMgr.allPhysicalVolumes.each do |v|
        	if $log.debug?
            	$log.debug "LinuxMount: v.dInfo.hardwareId = #{v.dInfo.hardwareId}"
            	$log.debug "LinuxMount: v.partNum.to_s = #{v.partNum.to_s}"
            	$log.debug "LinuxMount: @devHash[v.dInfo.hardwareId] = #{@devHash[v.dInfo.hardwareId]}"
            end
            @osNames[v.dInfo.hardwareId + ':' + v.partNum.to_s] = @devHash[v.dInfo.hardwareId] + v.partNum.to_s
        end
        
        #
        # Build a tree of file systems and their associated mont points.
        #
        @mountPoints = Hash.new
		$log.debug "LinuxMount: processing #{FSTAB_FILE_NAME}" if $log.debug?
        @rootFS.fileOpen(FSTAB_FILE_NAME) { |fo| fo.read }.each_line do |fstl|
			$log.debug "LinuxMount: fstab line: #{fstl}" if $log.debug?
            next if fstl =~ /^#.*$/ || fstl =~ /^\s*$/
            fsSpec, mtPoint = fstl.split(/\s+/)
			$log.debug "LinuxMount: fsSpec: #{fsSpec}, mtPoint: #{mtPoint}" if $log.debug?
            next if fsSpec == "none" || mtPoint == "swap"
            next if !(fs = fsSpecHash[fsSpec])
			$log.debug "LinuxMount: Adding fsSpec: #{fsSpec}, mtPoint: #{mtPoint}" if $log.debug?
            addMountPoint(mtPoint, fs, fsSpec)
        end
    end # def fs_init
    
    #
    # Given a path to a file, return true if it's a symbolic link.
    # Otherwise, return false.
    #
    def fileSymLink?(p)
        #
        # We can't just expand the links in the whole path,
        # because then, the target file will no longer be a link.
        # So, we expand the path to the target file, then open
        # the target file through that path to obtain the link data.
        #
        np = normalizePath(p)
        d = File.dirname(np)
        f = File.basename(np)
        
        # Expand the path to the target file.
        exp_dir = expandLinks(d)
        
        # Get the file system where the target file resides, and it's local path.
        fs, lp = getFsPathBase(File.join(exp_dir, f))
        return(fs.fileSymLink?(lp))
    end
    
    #
    # Given a path to a symbolic link, return the full
    # path to where the link points.
    #
    def getLinkPath(p)
        #
        # We can't just expand the links in the whole path,
        # because then, the target file will no longer be a link.
        # So, we expand the path to the target file, then open
        # the target file through that path to obtain the link data.
        #
        np = normalizePath(p)
        d = File.dirname(np)
        f = File.basename(np)
        
        # Expand the path to the target file.
        exp_dir = expandLinks(d)
        
        # Get the file system where the target file resides, and it's local path.
        fs, lp = getFsPathBase(File.join(exp_dir, f))
        # Read the link data from the file, through its file system.
        sp = getSymLink(fs, lp)
        # Construct and return the full path to the link target.
        return(sp) if sp[0,1] == '/'
        return(normalizePath(File.join(exp_dir, sp)))
    end
	
  	private
  	
  	def normalizePath(p)
        # When running on windows, File.expand_path will add a drive letter.
        # Remove it if it's there.
  		np = File.expand_path(p, @cwd).gsub(/^[a-zA-Z]:/, "")
  		# puts "LinuxMount::normalizePath: p = #{p}, np = #{np}"
  		return(np)
  	end
	
  	class PathNode
    	  attr_accessor :children, :fs
	  
    	  def initialize
      	    @children = Hash.new
      	    @fs = nil
    	  end
  	end # def PathNode
	
    #
    # Add the file system to the mount point tree.
    #
  	def addMountPoint(mp, fs, fsSpec)
  	    saveFs(fs, mp, fsSpec)
  	    return if mp == '/'
  	    path = mp.split('/')
  	    path.delete("")
  	    h = @mountPoints
  	    tn = nil
  	    path.each do |d|
  	        h[d] = PathNode.new if !h[d]
  	        tn = h[d]
  	        h = h[d].children
  	    end
  	    tn.fs = fs if tn
  	end
  	
  	#
  	# Expand symbolic links and perform mount indirection look up.
  	#
  	def getFsPath(path)
  	    if path.kind_of? Array
  	        if path.length == 0
  	            localPath = @cwd
  	        else
  	            localPath = normalizePath(path[0])
  	        end
  	    else
  	        localPath = normalizePath(path)
  	    end
  	    
  	    p = getFsPathBase(expandLinks(localPath))
  	    # getFsPathBase(path)
  	end
	
    #
    # Mount indirection look up.
    # Given a path, return its corresponding file system
    # and the part of the path relative to that file system.
    # It assumes symbolic links have already been expanded.
    #
  	def getFsPathBase(path)
  	    if path.kind_of? Array
  	        if path.length == 0
  	            localPath = @cwd
  	        else
  	            localPath = normalizePath(path[0])
  	        end
  	    else
  	        localPath = normalizePath(path)
  	    end
  	    
  	    fs = @rootFS
  	    p = localPath.split('/')
  	    p.delete("")
  	    
  	    h = @mountPoints
  	    while d = p.shift
  	        return fs, localPath if !h[d]
  	        if tfs = h[d].fs
  	            fs = tfs
  	            localPath = '/' + p.join('/')
  	        end
  	        h = h[d].children
  	    end
  	    return fs, localPath
  	end
  	
  	#
  	# Expand symbolic links in the path.
  	# This must be done here, because a symlink in one file system
  	# can point to a file in another filesystem.
  	#
  	def expandLinks(p)
	    cp = '/'
	    components = p.split('/')
	    components.shift if components[0] == "" # root
	    
	    #
	    # For each component of the path, check to see
	    # if it's a symbolic link. If so, expand it 
	    # relative to its base directory.
	    #
	    components.each do |c|
	        ncp = File.join(cp, c)
	        #
	        # Each file system know how to check for,
	        # and read its own links.
	        #
	        fs, lp = getFsPathBase(ncp)
	        if fs.fileSymLink?(lp)
	            sl = getSymLink(fs, lp)
	            if sl[0,1] == '/'
	                cp = sl
	            else
	                cp = File.join(cp, sl)
	            end
	        else
	            cp = ncp
	        end
	    end
	    return(cp)
	end
	
	def getSymLink(fs, p)
	    fs.fileOpen(p) { |lo| lo.read }
	end
    
end # module LinuxMount

