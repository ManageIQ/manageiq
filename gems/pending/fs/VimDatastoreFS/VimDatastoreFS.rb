$:.push("#{File.dirname(__FILE__)}/../../VMwareWebService")

module VimDatastoreFS
    
	def fs_init
	    # raise "Object dobj (#{dobj.class.to_s}) is not a MiqVimDataStore object" if !@dobj.kind_of? MiqVimDataStore
	    
	    @fsType = "VimDatastoreFS"
	    @fsId = @dobj.name
    	@volName = @dobj.name
    	
    	@rootStr = "[#{@dobj.name}]"
    	@dsHash = nil
	end

	def fs_dirEntries(p)
		raise "Directory: #{p} does not exist" if !(fi = getFileInfo(p))
	    raise "#{p} is not a directory" if !(fi["fileType"] =~ /.*FolderFileInfo/)
	    return(fi["dirEntries"])
	end

	def fs_fileExists?(p)
	    return(getFileInfo(p) == nil)
	end

	def fs_fileFile?(p)
	    return false if !(fi = getFileInfo(p))
	    return(fi["fileType"] != "FolderFileInfo")
	end

	def fs_fileDirectory?(p)
		return false if !(fi = getFileInfo(p))
	    return(fi["fileType"] =~ /.*FolderFileInfo/)
	end

	def fs_fileSize(p)
	    raise "File: #{p} does not exist" if !(fi = getFileInfo(p))
		return(fi["fileSize"])
	end
	
	# def fs_fileAtime(p)
	#     File.atime(p)
	# end
	# 
	# def fs_fileCtime(p)
	#     File.ctime(p)
    # end
    
    def fs_fileMtime(p)
        raise "File: #{p} does not exist" if !(fi = getFileInfo(p))
        return(fi["modification"])
    end
    
    # def fs_fileSize_obj(fobj)
	#     fs_fileSize(fobj.filePath)
	# end
    # 
    # def fs_fileAtime_obj(fobj)
    #     fobj.atime
    # end
    # 
    # def fs_fileCtime_obj(fobj)
    #     fobj.ctime
    # end
    # 
    # def fs_fileMtime_obj(fobj)
    #     fobj.mtime
    # end

	# def fs_fileOpen(p, mode="r")
	#     fread = fwrite = fcreate = ftruncate = fappend = false
	#     mode.delete!("b")
	#     
	#     case mode[0,1]
    #     when "r"
    #         fread     = true
    #         fwrite    = true if mode[-1,1] == "+"
    #     when "w"
    #         fwrite    = true
    #         fcreate   = true
    #         ftruncate = true
    #         fread     = true if mode[-1,1] == "+"
    #     when "a"
    #         fwrite    = true
    #         fcreate   = true
    #         fappend   = true
    #         fread     = true if mode[-1,1] == "+"
    #     else
    #         raise "Unrecognized open mode: #{mode}"
    #     end
    #     
	#     fileRow = nil
	#     fi = getFileIndex(p)
	#     
	#     if fi < 0
	#         #
	#         # Should we create the file? If not, fail.
	#         #
	#         raise "#{p}: No such file" if !fcreate
	#         
	#         #
	#         # Create the file if it doesn't exist.
	#         #
	#         fileRow = create(p, TYPE_FILE)
	#     else
	#         fileRow = @vFentry[fi]
	#     end
	#     
	#     fpos = 0
	#     fsize = @pSize.get(fileRow)
	#     if ftruncate && fsize != 0
	#         @pSize.set fileRow, 0
    #         @pData.set fileRow, Metakit::Bytes.new("", 0)
    #     elsif fappend
    #         fpos = fsize
	#     end
	#     
	#     return(MkFile.new(p, fileRow, fpos, fread, fwrite))
	# end # def fs_fileOpen

	# def fs_fileSeek(fobj, offset, whence)
	#     seekPos = 0
	#     case whence
    #         when IO::SEEK_CUR
    #             seekPos = filePos + amt
    #         when IO::SEEK_END
    #             seekPos = fs_fileSize_obj(fobj) + amt
    #         when IO::SEEK_SET
    #             seekPos = amt
    #         else
    #             raise "Invalid whence value: #{whence}"
    #     end
    #     raise "Invalid seek position: #{seekPos}" if seekPos < 0 || seekPos > fs_fileSize_obj(fobj)
    #     
    #     fobj.filePos = seekPos
	# end

	# def fs_fileRead(fobj, len)
	#     dataRef = @pData.ref(fobj.fileRow)
    #     rb = dataRef.access(fobj.filePos, len)
    #     fobj.filePos += rb.size
    #     return(rb.contents)
	# end

	# def fs_fileClose(fobj)
	# 	return
	# end
	
	def dsPath(p)
        return(p) if p[0,1] == "["
        return(path2key(normalizePath(p)))
    end
    
    def fileInfo(p)
        return(dsHash[dsPath(p)])
    end
    
    def reset
        @dsHash = nil
    end
	
	private
	
	def path2key(p)
	    return(@rootStr) if p == "/"
	    return(@rootStr + " " + p[1..-1])
    end
    
    def dsHash
	    return(@dsHash) if @dsHash
	    @dsHash = @dobj.dsHash(true)
	    return(@dsHash)
    end
	
	def method_missing(methodId)
	    raise "#{self.class}: #{methodId.id2name} is not supported"
    end
    
    def getFileInfo(p)
        k = path2key(p)
        return(dsHash[k])
    end
    
    # class DsFile
    #     attr_accessor :filePath, :fileRow, :filePos, :fileRead, :fileWrite
    #     
    #     def initialize(path, fileRow, fpos, fread, fwrite)
    #         @filePath  = path
    #         @fileRow   = fileRow
    #         @filePos   = fpos
    #         @fileRead  = fread
    #         @fileWrite = fwrite
    #     end
    # end # class MkFile
	
end # module VimDatastoreFS
