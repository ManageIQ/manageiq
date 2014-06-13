module RealFS
	
	attr_reader :guestOS
	
	def fs_init
		case Platform::IMPL
			when :mswin, :mingw
				self.fsType = "NTFS"
				@guestOS = "Windows"
			when :linux
				self.fsType = `df -T / | tail -1 | awk '{ print $2 }'`
				@guestOS = "Linux"
			when :macosx
		end
	end

	def fs_dirEntries(p)
		Dir.entries(p)
	end

	def fs_fileExists?(p)
		File.exists?(p)
	end

	def fs_fileFile?(p)
		File.file?(p)
	end

	def fs_fileDirectory?(p)
		File.directory?(p)
	end

	def fs_fileSize(p)
		File.size(p)
	end
	
	def fs_fileSize_obj(fobj)
	    fobj.stat.size
	end
	
	def fs_fileAtime(p)
	    File.atime(p)
	end
	
	def fs_fileCtime(p)
	    File.ctime(p)
    end
    
    def fs_fileMtime(p)
        File.mtime(p)
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
		File.new(p, mode)
	end

	def fs_fileSeek(fobj, offset, whence)
		fobj.seek(offset, whence)
	end

	def fs_fileRead(fobj, len)
		fobj.read(len)
	end

	def fs_fileClose(fobj)
		fobj.close
	end
end
