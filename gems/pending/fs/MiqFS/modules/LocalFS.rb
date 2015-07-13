module LocalFS
	def fs_init
		self.fsType = "LocalFS"
		
		if @dobj && @dobj.root
			@root = @dobj.root
			raise "LocalFS: root directory does not exist, #{@root}" if !File.directory?(@root)
		else
			@root = nil
		end
		
		@cwd = Dir.pwd
	end
	
	def freeBytes
		return(0)
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
		File.exist?(internalPath(p))
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
		raise "LocalFS.fs_fileWrite: attempt to write passed the end of buffer"
	end

	def fs_fileClose(fobj)
		fobj.close
	end
	
	def internalPath(p)
		return(File.join(@root, p)) if @root
		return(p)
	end
end
