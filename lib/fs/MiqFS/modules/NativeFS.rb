module NativeFS

	MOUNT_DIR	= "/miq_mounts"
	VOL_ID		= "/KNOPPIX/lib/udev/vol_id"
	
	def self.supported?(dobj)
		devNode	= dobj.devFile
		fsType = `fstype #{devNode}`.chomp
		$log.debug "NativeFS.supported?: devNode = #{devNode}, fsType = #{fsType}" if $log.debug?
		
		return(false) if fsType.empty? || fsType == "auto" || fsType == "swap"
		return(true)
	end
	
	def fs_init
		dInfo = @dobj.dInfo
		raise "NativeFS: disk is not a local device" if !@dobj.devFile

		@devNode	= @dobj.devFile
		
		self.fsType = `fstype #{@devNode}`.chomp
		raise "NativeFS: cannot determine filesystem type for: #{@devNode}" if self.fsType.empty?
		
		@volName	= `#{VOL_ID} -l #{@devNode}`.chomp
		@fsId		= `#{VOL_ID} -u #{@devNode}`.chomp
		
		if dInfo.lvObj
			lv = "#{dInfo.lvObj.vgObj.vgName}-#{dInfo.lvObj.lvName}"
			@mountPoint = File.join(MOUNT_DIR, lv)
			@devNode	= File.join("/dev/mapper", lv)
		else
			@mountPoint = File.join(MOUNT_DIR, File.basename(@devNode))
		end
		
		if $log.debug?
			$log.debug "NativeFS.fs_init: devNode		= #{@devNode}"
			$log.debug "NativeFS.fs_init: fsType 		= #{self.fsType}"
			$log.debug "NativeFS.fs_init: volName 		= #{@volName}"
			$log.debug "NativeFS.fs_init: fsId 			= #{@fsId}"
		end
		
		return if isMounted?(@devNode)
		system("mkdir", "-p", @mountPoint)
		$log.debug "NativeFS.fs_init: mounting #{@devNode} on #{@mountPoint}" if $log.debug?
		if !system("mount", @devNode, @mountPoint)
			raise "NativeFS: Could not mount #{@devNode} on #{@mountPoint}, exit status: #{$?.exitstatus}"
		end
	end
	
	def fs_umount
		raise "NativeFS: #{@devNode} is not mounted" if @mountPoint.nil?
		$log.debug "NativeFS.fs_umount: unmounting #{@mountPoint}" if $log.debug?
		if !system("umount", @mountPoint)
			raise "NativeFS: Could not unmount #{@devNode} from #{@mountPoint}, exit status: #{$?.exitstatus}"
		end
		@mountPoint = nil
	end
	
	def freeBytes
		raise "NativeFS: #{@devNode} is not mounted" if @mountPoint.nil?
		return(`df -lPB1 | grep '#{@mountPoint}$' | awk '{ print $4 }'`.chomp.to_i)
	end

	def fs_dirEntries(p)
		Dir.entries(internalPath(p))
	end
	
	def fs_dirMkdir(p)
		Dir.mkdir(internalPath(p))
	end
		
	def dirRmdir(p)
		Dir.rmdir(internalPath(p))
	end
	
	def fs_fileDelete(p)
		File.delete(internalPath(p))
	end

	def fs_fileExists?(p)
		File.exists?(internalPath(p))
	end

	def fs_fileFile?(p)
		File.file?(internalPath(p))
	end

	def fs_fileDirectory?(p)
		File.directory?internalPath((p))
	end

	def fs_fileSize(p)
		File.size(internalPath(p))
	end
	
	def fs_fileSize_obj(fobj)
	    fobj.stat.size
	end
	
	def fs_fileAtime(p)
	    File.atime(internalPath(p))
	end
	
	def fs_fileCtime(p)
	    File.ctime(internalPath(p))
    end
    
    def fs_fileMtime(p)
        File.mtime(internalPath(p))
    end
    
    def fs_fileAtime_obj(fobj)
        fobj.atime
    end
    
    def fs_fileCtime_obj(fobj)
        fobj.ctime
    end
    
    def fs_fileMtime_obj(fobj)
        fobj.mtime
    end

	def fs_fileOpen(p, mode="r")
		File.new(internalPath(p), mode)
	end

	def fs_fileSeek(fobj, offset, whence)
		fobj.seek(offset, whence)
	end

	def fs_fileRead(fobj, len)
		fobj.read(len)
	end
	
	def fs_fileWrite(fobj, buf, len)
		return(fobj.write(buf))			if buf.length == len
		return(fobj.write(buf[0, len]))	if buf.length > len
		raise "NativeFS.fs_fileWrite: attempt to write passed the end of buffer"
	end

	def fs_fileClose(fobj)
		fobj.close
	end
	
	def internalPath(p)
		raise "NativeFS: #{@devNode} is not mounted" if @mountPoint.nil?
		return(File.join(@mountPoint, p))
	end
	
	def isMounted?(dev)
		`mount`.each { |ml| return(true) if ml.split(" ", 2)[0] == dev }
		return(false)
	end
	private :isMounted?
end
