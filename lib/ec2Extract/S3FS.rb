$:.push("#{File.dirname(__FILE__)}/../fs/MiqFS")

require 'rubygems'
require 'aws-sdk'
require 'MiqFS'

module S3FS
	
	def self.new(dobj)
		return(MiqFS.new(self, dobj))
	end
	
	def fs_init
	    @fsType = "S3FS"
	    @fsId = @dobj[:bucket]
    	@volName = @dobj[:bucket]
    	
    	@s3Hash = Hash.new
		@s3Hash['/'] = {}

		begin
			$log.debug "S3FS: processing bucket [#{@dobj[:bucket]}]"
			raise "Can't find bucket #{@dobj[:bucket]}" if s3bucket(@dobj[:bucket]).nil?
			s3bucket(@dobj[:bucket]).objects.each { |obj| addObj("/" + obj.key, obj) }
			$log.debug "S3FS: bucket processing complete"
		end
	end

	def fs_dirEntries(p)
		raise "Directory: #{p} does not exist" if !(fi = getFileInfo(p))
	    raise "#{p} is not a directory" if fi.kind_of?(AWS::S3::S3Object)
	    return(fi.keys)
	end

	def fs_fileExists?(p)
	    return(!getFileInfo(p).kind_of?(NilClass))
	end

	def fs_fileFile?(p)
	    return false if !(fi = getFileInfo(p))
	    return(fi.kind_of?(AWS::S3::S3Object))
	end

	def fs_fileDirectory?(p)
		return false if !(fi = getFileInfo(p))
	    return(!fi.kind_of?(AWS::S3::S3Object))
	end

	def fs_fileSize(p)
	    raise "File: #{p} does not exist" if !(fi = getFileInfo(p))
		raise "File: #{p} is a directory" if !fi.kind_of?(AWS::S3::S3Object)
		return(fi.content_length)
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
        return(fi.last_modified)
    end
    
    def fs_fileSize_obj(fobj)
	    fs_fileSize(fobj.filePath)
	end
    # 
    # def fs_fileAtime_obj(fobj)
    #     fobj.atime
    # end
    # 
    # def fs_fileCtime_obj(fobj)
    #     fobj.ctime
    # end
    # 
    def fs_fileMtime_obj(fobj)
        fs_fileMtime(fobj.filePath)
    end

	def fs_fileOpen(p, mode="r")
	    fread = fwrite = fcreate = ftruncate = fappend = false
	    mode.delete!("b")
	    
	    case mode[0,1]
        when "r"
            fread     = true
            # fwrite    = true if mode[-1,1] == "+"
        when "w"
            # fwrite    = true
            # fcreate   = true
            # ftruncate = true
            fread     = true if mode[-1,1] == "+"
        when "a"
            # fwrite    = true
            # fcreate   = true
            # fappend   = true
            fread     = true if mode[-1,1] == "+"
        else
            raise "Unrecognized open mode: #{mode}"
        end
        
	    fi = getFileInfo(p)
	    
	    if !fi
	        #
	        # Should we create the file? If not, fail.
	        #
	        raise "#{p}: No such file" if !fcreate
	    end
	    
	    fpos = 0
	    if ftruncate && fsize != 0
	        @pSize.set fileRow, 0
            @pData.set fileRow, Metakit::Bytes.new("", 0)
        elsif fappend
            fpos = fsize
	    end
	    
	    return(S3File.new(p, fi, fpos, fread, fwrite))
	end # def fs_fileOpen

	def fs_fileSeek(fobj, offset, whence)
	    seekPos = 0
	    case whence
            when IO::SEEK_CUR
                seekPos = filePos + amt
            when IO::SEEK_END
                seekPos = fs_fileSize_obj(fobj) + amt
            when IO::SEEK_SET
                seekPos = amt
            else
                raise "Invalid whence value: #{whence}"
        end
        raise "Invalid seek position: #{seekPos}" if seekPos < 0 || seekPos > fs_fileSize_obj(fobj)
        
        fobj.filePos = seekPos
	end

	def fs_fileRead(fobj, len)
		range = Range.new(fobj.filePos, (fobj.filePos+len))
		rb    = fobj.fileInfo.read(:range => range)
		fobj.filePos += rb.size
		return(rb)
	end

	def fs_fileClose(fobj)
		return
	end
    
    def fileInfo(p)
        return(@s3Hash[p])
    end
	
	private

	def s3
		@s3 ||= AWS::S3.new
	end

	def s3bucket(name)
		@s3buckets       ||= {}
		@s3buckets[name] ||= s3.buckets[name]
	end

	def addObj(path, obj)
		return if path == "/"
		@s3Hash[path] = obj || Hash.new
		dir, file = File.split(path)
		addObj(dir, nil) if !@s3Hash[dir]
		children = @s3Hash[dir]
		children[file] = true
	end
	
	def method_missing(methodId)
	    raise "#{self.class}: #{methodId.id2name} is not supported"
    end
    
    def getFileInfo(p)
        return(@s3Hash[p])
    end
    
    class S3File
        attr_accessor :filePath, :fileInfo, :filePos, :fileRead, :fileWrite
        
        def initialize(path, fileInfo, fpos, fread, fwrite)
            @filePath  = path
            @fileInfo  = fileInfo
            @filePos   = fpos
            @fileRead  = fread
            @fileWrite = fwrite
        end
    end # class S3File
	
end # module S3FS
