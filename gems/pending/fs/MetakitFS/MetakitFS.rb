# encoding: US-ASCII

require 'rubygems'
require 'mk4rb'

module MetakitFS
    
    MK_FENTRY   = "fentry[fpath:S,ftype:I,fsize:I,ftags:B,fdata:B]"
    MK_HASHVW   = "sec[_H:I,_R:I]"
    
    TYPE_FILE       = 1
    TYPE_DIR        = 2
    TYPE_SYMLINK    = 3

	def self.supported?(dobj)
		return(false) if !dobj.mkfile
		storage = Metakit::Storage.open(dobj.mkfile, 1)
		return(false) if storage.description != "#{MK_FENTRY},#{MK_HASHVW}"
		return(true)
	end
    
	def fs_init
	    raise "No metakit file has been specified" if !@dobj.mkfile
	    @storage = Metakit::Storage.open(@dobj.mkfile, 1)
	    
	    newFs = false
	    if @storage.description != "#{MK_FENTRY},#{MK_HASHVW}"
	        raise "#{@dobj.mkfile} is not a MetakitFS" if !@dobj.create
	        newFs = true
	    end
	    
	    self.fsType = "MetakitFS"
	    
	    vData       = @storage.get_as MK_FENTRY
        vSec        = @storage.get_as MK_HASHVW
        @vFentry    = vData.hash(vSec, 1)
        
        @pPath = Metakit::StringProp.new "fpath"
        @pType = Metakit::IntProp.new    "ftype"
        @pSize = Metakit::IntProp.new    "fsize"
        @pTags = Metakit::BytesProp.new  "ftags"
        @pData = Metakit::BytesProp.new  "fdata"
        
        @findRow = Metakit::Row.new
        
        #
        # If we're creating a new file system, create the root directory.
        #
        if newFs
            create("/", TYPE_DIR)if newFs
            @storage.commit
        end

		labels = fs_tagValues("/", "LABEL")
		@fsId = labels[0] if !labels.empty?
	end

	def fs_dirEntries(p)
		raise "Directory: #{p} does not exist" if (i = getFileIndex(p)) < 0
	    raise "#{p} is not a directory" if @pType.get(@vFentry[i]) != TYPE_DIR
	    
	    data = @pData.get(@vFentry[i])
	    return [] if data.size == 0
	    return data.contents.split("\0")
	end
	
	def fs_dirMkdir(p)
	    #
	    # If the target exists, succeed if it is a directory, otherwise fail.
	    #
	    if (i = getFileIndex(p)) >= 0
	        return if @pType.get(@vFentry[i]) == TYPE_DIR
	        raise "Cannot create directory, #{p}: file exists"
	    end
	    
	    #
	    # Create the directory.
	    #
	    create(p, TYPE_DIR)
        
        #
        # Apply changes to database.
        #
        @storage.commit
	end
	
	def fs_dirRmdir(p)
	    #
	    # Before we can remove a directory, it must:
	    # exist, be a directory and be empty.
	    #
	    raise "#{p}: no such directory" if (di = getFileIndex(p)) < 0
	    dirRow = @vFentry[di]
	    raise "#{p}: not a directory" if @pType.get(dirRow) != TYPE_DIR
	    raise "#{p}: directory not empty" if @pSize.get(dirRow) != 0
	    
	    rmCommon(p, di)
    end

	def fs_fileExists?(p)
	    return false if getFileIndex(p) < 0
		return true
	end

	def fs_fileFile?(p)
	    return false if (i = getFileIndex(p)) < 0
	    return true  if @pType.get(@vFentry[i]) == TYPE_FILE
	    return false
	end

	def fs_fileDirectory?(p)
		return false if (i = getFileIndex(p)) < 0
	    return true  if @pType.get(@vFentry[i]) == TYPE_DIR
	    return false
	end

	def fs_fileSize(p)
	    raise "File: #{p} does not exist" if ((i = getFileIndex(p)) < 0)
		return(@pSize.get(@vFentry[i]))
	end
	
	def fs_fileSize_obj(fobj)
	    return(@pSize.get(fobj.fileRow))
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
	    fread = fwrite = fcreate = ftruncate = fappend = false
	    mode.delete!("b")
	    
	    case mode[0,1]
        when "r"
            fread     = true
            fwrite    = true if mode[-1,1] == "+"
        when "w"
            fwrite    = true
            fcreate   = true
            ftruncate = true
            fread     = true if mode[-1,1] == "+"
        when "a"
            fwrite    = true
            fcreate   = true
            fappend   = true
            fread     = true if mode[-1,1] == "+"
        else
            raise "Unrecognized open mode: #{mode}"
        end
        
	    fileRow = nil
	    fi = getFileIndex(p)
	    
	    if fi < 0
	        #
	        # Should we create the file? If not, fail.
	        #
	        raise "#{p}: No such file" if !fcreate
	        
	        #
	        # Create the file if it doesn't exist.
	        #
	        fileRow = create(p, TYPE_FILE)
	        fi = getFileIndex(p)
	    else
	        fileRow = @vFentry[fi]
	    end
	    	    
	    fpos = 0
	    fsize = @pSize.get(fileRow)
	    if ftruncate && fsize != 0
	        @pSize.set fileRow, 0
            @pData.set fileRow, Metakit::Bytes.new("", 0)
            @storage.commit
        elsif fappend
            fpos = fsize
	    end
	    
	    return(MkFile.new(p, fileRow, fpos, fread, fwrite))
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
	    dataRef = @pData.ref(fobj.fileRow)
        rb = dataRef.access(fobj.filePos, len)
        fobj.filePos += rb.size
        return(rb.contents) if rb.contents.length > 0
		return(nil)
	end
	
	def fs_fileWrite(fobj, buf, len)
	    raise "fs_fileWrite: write length is larger than buffer" if len > buf.length
	    size = fs_fileSize_obj(fobj)
	    
	    if fobj.filePos == size
	        #
	        # We're appending to the end of the file, so we can just use the
	        # modify operation to add the data to the end of the file.
	        #
	        dataRef = @pData.ref(fobj.fileRow)
            data = Metakit::Bytes.new(buf, len)
            dataRef.modify(data, size, len)
            @pSize.set(fobj.fileRow, size + len)
            fobj.filePos += len
            @storage.commit
            return(len)
        end
        #
        # The Metakit modify operation inserts data. So if we need to overwrite
        # existing data, we must read the whole file, modify the data, and write
        # it out again.
        #
        dataStr = @pData.get(fobj.fileRow).contents
        dataStr[fobj.filePos, len] = buf[0, len]
        data = Metakit::Bytes.new(dataStr, dataStr.length)
        @pData.set(fobj.fileRow, data)
        @pSize.set(fobj.fileRow, dataStr.length)
        @storage.commit
        return(len)
	end

	def fs_fileClose(fobj)
		return
	end
	
	def fs_fileDelete(p)
	    #
	    # Before we can remove a directory, it must:
	    # exist, be a directory and be empty.
	    #
	    raise "#{p}: no such file" if (fi = getFileIndex(p)) < 0
	    dirRow = @vFentry[di]
	    raise "#{p}: is a directory" if @pType.get(dirRow) == TYPE_DIR
	    
	    rmCommon(p, fi)
    end

	def tagAdd(p, tag)
		fs_tagAdd(normalizePath(p), tag)
	end

	def fs_tagAdd(p, tag)
		raise "Path: #{p} does not exist" if (i = getFileIndex(p)) < 0
		fileRow = @vFentry[i]
		fs_tagAddCommon(fileRow, tag)
	end
    
    def fs_fileTagAdd(fobj, tag)
		fs_tagAddCommon(fobj.fileRow, tag)
    end

	def fs_tagAddCommon(fileRow, tag)
		tagStr = @pTags.get(fileRow).contents
	    tags = tagStr.split("\0")
	    return if tags.include? tag
	    tags << tag
	    tagStr = tags.join("\0")
	    @pTags.set(fileRow, Metakit::Bytes.new(tagStr, tagStr.length))
		@storage.commit
	end
	
	def tagDelete(p, tag)
		fs_tagDelete(normalizePath(p), tag)
	end
	
	def fs_tagDelete(p, tag)
		raise "Path: #{p} does not exist" if (i = getFileIndex(p)) < 0
		fileRow = @vFentry[i]
		fs_tagDeleteCommon(fileRow, tag)
	end
	
	def fs_fileTagDelete(fobj, tag)
		fs_tagDeleteCommon(fobj.fileRow, tag)
	end
    
    def fs_tagDeleteCommon(fileRow, tag)
	    tagStr = @pTags.get(fileRow).contents
	    tags = tagStr.split("\0")
	    tags.delete(tag) { raise "Tag #{tag} not found" }
	    tagStr = tags.join("\0")
	    @pTags.set(fileRow, Metakit::Bytes.new(tagStr, tagStr.length))
		@storage.commit
    end

	def tags(p)
		fs_tags(normalizePath(p))
	end

	def fs_tags(p)
		raise "Path: #{p} does not exist" if (i = getFileIndex(p)) < 0
		fileRow = @vFentry[i]
		fs_tagsCommon(fileRow)
	end
	
	def fs_fileTags(fobj)
		fs_tagsCommon(fobj.fileRow)
	end
    
    def fs_tagsCommon(fileRow)
        tags = @pTags.get(fileRow)
	    return [] if tags.size == 0
	    return tags.contents.split("\0")
    end

	def hasTagName?(p, tag)
		fs_hasTagName?(normalizePath(p), tag)
	end

	def fs_hasTagName?(p, tagName)
		raise "Path: #{p} does not exist" if (i = getFileIndex(p)) < 0
		fileRow = @vFentry[i]
		fs_hasTagNameCommon?(fileRow, tagName)
	end
	
	def fs_fileHasTagName?(fobj, tagName)
		fs_hasTagNameCommon?(fobj.fileRow, tagName)
	end
    
    def fs_hasTagNameCommon?(fileRow, tagName)
        fs_tagsCommon(fileRow).each { |t| return true if t =~ /#{tagName}(=.*)*$/ }
        return false
    end

	def hasTag?(p, tag)
		fs_hasTag?(normalizePath(p), tag)
	end

	def fs_hasTag?(p, tag)
		raise "Path: #{p} does not exist" if (i = getFileIndex(p)) < 0
		fileRow = @vFentry[i]
		fs_hasTagCommon?(fileRow, tag)
	end
	
	def fs_fileHasTag?(fobj, tag)
		fs_tagsCommon(fobj.fileRow).include?(tag)
	end
    
    def fs_hasTagCommon?(fileRow, tag)
        return fs_tagsCommon(fileRow).include?(tag)
    end

	def tagValues(p, tag)
		fs_tagValues(normalizePath(p), tag)
	end

	def fs_tagValues(p, tag)
		raise "Path: #{p} does not exist" if (i = getFileIndex(p)) < 0
		fileRow = @vFentry[i]
		fs_tagValuesCommon(fileRow, tag)
	end
	
	def fs_fileTagValues(fobj, tag)
		fs_tagValuesCommon(fobj.fileRow, tag)
	end
    
    def fs_tagValuesCommon(fileRow, tag)
        values = Array.new
        tagFound = false
        fs_tagsCommon(fileRow).each do |t|
            if t =~ /#{tag}(=(.*))*$/
                tagFound = true
                values << $2 if $2
            end
        end
        
        return [] if !tagFound
        return values
    end
    
    def fs_fileObjExtend(fo)
        fo.instance_eval("extend MkFileMod")
    end
	
	private
	
	def getFileIndex(p)
        @pPath.set @findRow, p
        return(@vFentry.find(@findRow, 0))
    end
    
    def rmCommon(p, idx)
	    #
	    # If we get here, the parent hast to exist and it has to be a directory,
	    # so if it isn't, there's a bug somewhere.
	    #
	    parent = File.dirname(p)
	    raise "[BUG] #{parent}: no such directory" if (pi = getFileIndex(parent)) < 0
	    parentRow = @vFentry[pi]
	    raise "[BUG] #{parent}: not a directory" if @pType.get(parentRow) != TYPE_DIR
	    
	    #
	    # First, remove the reference in the parent directory.
	    #
	    dirName = File.basename(p)
	    dataStr = @pData.get(parentRow).contents
	    dirEnts = dataStr.split("\0")
	    dirEnts.delete(dirName) { raise "[BUG] Directory #{parent} does not contain entry for #{dirName}" }
	    dataStr = dirEnts.join("\0")
	    @pData.set(parentRow, Metakit::Bytes.new(dataStr, dataStr.length))
	    
	    #
	    # Then, remove the directory's row from the database.
	    #
	    @vFentry.remove_at(idx)
	    
	    #
        # Apply changes to database.
        #
	    @storage.commit
	end
    
    def create(p, type)
        #
	    # Fail if the parent component of the path doesn't exist,
	    # or if it is not a directory.
	    #
	    if p != "/"
    	    parent = File.dirname(p)
    	    raise "#{parent}: no such directory" if (i = getFileIndex(parent)) < 0
    	    parentRow = @vFentry[i]
    	    raise "#{parent}: not a directory" if @pType.get(parentRow) != TYPE_DIR
	    end

	    #
	    # Create the new empty file or directory.
	    #
	    newRow = Metakit::Row.new
        @pPath.set newRow, p
        @pType.set newRow, type
        @pSize.set newRow, 0
        @pTags.set newRow, Metakit::Bytes.new("", 0)
        @pData.set newRow, Metakit::Bytes.new("", 0)
        @vFentry.add newRow
        
        if p != "/" 
            #
            # Then, add an entry for the new file or directory in its parent.
            #
            dirName = File.basename(p) + "\0"
            dataRef = @pData.ref(parentRow)
            data = Metakit::Bytes.new(dirName, dirName.length)
            size = @pSize.get(parentRow)
            dataRef.modify(data, size, data.size)
            @pSize.set(parentRow, size + data.size)
        end
        
        @storage.commit
        
        fi = getFileIndex(p)
	    raise "[BUG] can't find new file: #{p}" if fi < 0
	        
	    #
	    # Must use row obtained through @vFentry.
	    #
        return(@vFentry[fi])
    end
    
    class MkFile
        attr_accessor :filePath, :fileRow, :filePos, :fileRead, :fileWrite
        
        def initialize(path, fileRow, fpos, fread, fwrite)
            @filePath  = path
            @fileRow   = fileRow
            @filePos   = fpos
            @fileRead  = fread
            @fileWrite = fwrite
        end
    end # class MkFile
	
end # module MetakitFS

module MkFileMod
    
    def addTag(tag)
        @fs.fs_fileTagAdd(@fobj, tag)
    end
    
    def deleteTag(tag)
        @fs.fs_fileTagDelete(@fobj, tag)
    end
    
    def tags
        @fs.fs_fileTags(@fobj)
    end
    
    def hasTagName?(tagName)
        @fs.fs_fileHasTagName?(@fobj, tagName)
    end
    
    def hasTag?(tag)
        @fs.fs_fileHasTag?(@fobj, tag)
    end
    
    def tagValues(tag)
        @fs.fs_fileTagValues(@fobj, tag)
    end
    
end
