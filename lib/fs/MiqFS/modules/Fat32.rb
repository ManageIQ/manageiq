require 'rufus/lru'

# Fat32 stuff.
$:.push("#{File.dirname(__FILE__)}/../../fat32")
$:.push("#{File.dirname(__FILE__)}/../fs/fat32") #This path is necessary when testing.
require 'Fat32BootSect'
require 'Fat32Directory'
require 'Fat32DirectoryEntry'
require 'Fat32FileData'

# Fat32 file system interface to MiqFS.
module Fat32
  
	# Default directory cache size.
	DEF_CACHE_SIZE = 50
	
  # Members (these become members of an MiqFS instance).
  attr_accessor :boot_sector, :drive_root, :dir_cache, :cache_hits
  attr_accessor :rootDirEnt
	
  # Top level file object.
  class FileObject
    
    include Fat32
    attr_reader :path, :de, :data, :miqfs, :dirty, :parentDirCluster
    # NOTE: miqfs will always be an MiqFS instance.
    
    # fs_fileOpen passes 'self' into .. er, 'this'.
    def initialize(path, miqfs)
      @path = path
      @miqfs = miqfs
			@dirty = false
    end
    
    def open(mode = "r")
      # Fat32 module methods use miqfs instance accessors to touch @boot_sector.
			@mode = mode.downcase
			@de = ifs_getFile(@path, @miqfs)
			if @de != nil
				raise "File is directory: '#{@path}'" if @de.isDir?
			end
			if mode.include?("r")
				raise "File not found: '#{@path}'" if @de == nil
				@data = FileData.new(@de, @miqfs.boot_sector)
			end
			if mode.include?("w")
				@de.delete(@miqfs.boot_sector) if @de != nil
				@de, @parentDirCluster = ifs_putFile(@path, @miqfs)
				@data = FileData.new(@de, @miqfs.boot_sector)
			end
			if mode.include?("a")
				@de, @parentDirCluster = ifs_putFile(@path, @miqfs) if @de == nil
				@data = FileData.new(@de, @miqfs.boot_sector) if @data == nil
				@data.read
			end
    end
  end
  
  # File system interface.
  def fs_init
		#puts "Fat32::fs_init(#{@dobj.dInfo.fileName})"
    self.fsType = "FAT32"
    
    # Initialize bs & read root dir.
		@dobj.seek(0, IO::SEEK_SET)
    self.boot_sector = BootSect.new(@dobj)
		self.drive_root = Directory.new(@boot_sector)
		self.dir_cache = LruHash.new(DEF_CACHE_SIZE)
		self.cache_hits = 0
		
		# Volume info: Note that fsId is a long in this case (not a UUID)
		# and volName could be modified by a file in the root with the label attrib set.
		self.fsId = self.boot_sector.fsId
		self.volName = self.boot_sector.volName
		
		# Spoof root dir ent - Fat32 has no "." in root.
		self.rootDirEnt = DirectoryEntry.new
		self.rootDirEnt.setAttribute(DirectoryEntry::FA_DIRECTORY)
		self.rootDirEnt.firstCluster = 0
		self.rootDirEnt.zeroTime
  end
	
	# Returns free space on file system in bytes.
	def fs_freeBytes
		return @boot_sector.freeClusters * @boot_sector.bytesPerCluster
	end
	
	#
	# Directory instance methods.
	#
  
  # Returns String array of all names, sans path.
  def fs_dirEntries(p)
    # Get path directory.
    dir = ifs_getDir(p)
    return nil if dir == nil
    return dir.globNames
  end
	
	# Make a directory. Parent must exist.
	def fs_dirMkdir(p)
		de = ifs_getFile(p)
		raise "Name already exists: #{p}" if de != nil
		parent, name = File.split(p)
		parent = ifs_getDir(parent)
		raise "Parent directory must exist: #{p}" if parent.nil?
		parent.mkdir(name)
	end
	
	# Remove a directory.
	def fs_dirRmdir(p)
		raise "Directory [#{p}] is not empty" if ifs_getDir(p).globNames.size > 2
		fs_fileDelete(p)
	end
	
	#
	# File instance methods.
	#
	
	# Returns true if name exists, false if not.
  def fs_fileExists?(p)
		return true if p == "/" or p == "\\"
    de = ifs_getFile(p)
    return false if de == nil
    return true
  end
	
  # Returns true if name is a regular file.
  # NOTE: If a name isn't a directory, it's always a file - so far...
  # (FAT32 supports .lnk files at this level, so this should also).
  def fs_fileFile?(p)
    de = ifs_getFile(p)
    return false if de == nil
    return false if de.isDir?
    return true
  end

  # Returns true if name is a directory.
  def fs_fileDirectory?(p)
    de = ifs_getFile(p)
    return false if de == nil
    return de.isDir?
  end
  
  # FAT file systems don't do symbolic links.
  def fs_isSymLink?(p)
    return false
  end
  
  # Returns size in bytes.
  def fs_fileSize(p)
    de = ifs_getFile(p)
    return nil if de == nil
    return de.length
  end
	
	# Delete file.
	def fs_fileDelete(p)
		de = ifs_getFile(p)
		return if de == nil
		de.delete(@boot_sector)
	end
	
  # Returns Ruby Time object.
  def fs_fileAtime(p)
    de = ifs_getFile(p)
    return nil if de == nil
    return de.aTime
  end
	
  # Returns Ruby Time object.
  def fs_fileCtime(p)
    de = ifs_getFile(p)
    return nil if de == nil
    return de.cTime
  end

  # Returns Ruby Time object.
  def fs_fileMtime(p)
    de = ifs_getFile(p)
    return nil if de == nil
    return de.mTime
  end

  # In these, fobj is a FileObject.
  
  def fs_fileSize_obj(fobj)
    fobj.de.length
  end
  
  # Returns a Ruby Time object.
  def fs_fileAtime_obj(fobj)
    fobj.de.aTime
  end

  # Returns a Ruby Time object.
  def fs_fileCtime_obj(fobj)
    fobj.de.cTime
  end

  # Returns a Ruby Time obect.
  def fs_fileMtime_obj(fobj)
    fobj.de.mTime
  end
  
  # New FileObject instance.
  # NOTE: FileObject must have access to Fat32 members.
  # This is kind of like a 'skip this' thing. Fat32 methods
  # use stuff owned by MiqFS, so this is necessary.
  def fs_fileOpen(p, mode="r")
    fobj = FileObject.new(p, self)
    fobj.open(mode)
    return fobj
  end

	# Returns current file position.
  def fs_fileSeek(fobj, offset, whence)
    fobj.data.seek(offset, whence)
  end

  # Returns a Ruby String object.
  def fs_fileRead(fobj, len)
    fobj.data.read(len)
  end

	def fs_fileWrite(fobj, buf, len)
		fobj.data.write(buf, len)
	end
	
  # Write changes & destroy.
  def fs_fileClose(fobj)
		fobj.data.close
		fobj = nil
  end
  
  # IFS members: internal file system.
  
  # Return a DirectoryEntry for a given file or nil if not exist.
  def ifs_getFile(p, miqfs = nil)
    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an Fat32 module method, then self owns contained instance members.
    miqfs = self if miqfs == nil
    
		# If root dir return spoof dir ent.
		return self.rootDirEnt if p == "/" or p == "\\"
		
    # Preprocess path.
    p = unnormalizePath(p)
    dir, fil = File.split(p)
    
    # Look for file in dir, but don't barf if it doesn't exist.
    # NOTE: if p is a directory that's ok, find it.
    begin
      dirObj = ifs_getDir(dir, miqfs)
      return nil if dirObj == nil
			# Do NOT explicitly pass FE_FILE.
      dirEnt = dirObj.findEntry(fil)
      return nil if dirEnt == nil      
    rescue RuntimeError
			return nil
    end
    return dirEnt
  end
  
  # Create a directory entry.
	def ifs_putFile(p, miqfs = nil)
    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an Fat32 module method, then self owns contained instance members.
    miqfs = self if miqfs == nil
    
    # Preprocess path.
    p = unnormalizePath(p)
    dir, fil = File.split(p)
		
    # Parent directory must exist.
		dir = ifs_getDir(dir, miqfs)
		return nil if dir == nil
    return dir.createFile(fil)
  end
		
	# Return a Directory object for a path.
  # Raise error if path doesn't exist.
  def ifs_getDir(p, miqfs = nil)
    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an NTFS module method, then self owns contained instance members.
    miqfs = self if miqfs == nil
    
    # Wack leading drive.
    p = unnormalizePath(p)

		# Check for this path in the cache.
		if miqfs.dir_cache.has_key?(p)
			miqfs.cache_hits += 1
			return Directory.new(miqfs.boot_sector, miqfs.dir_cache[p])
		end

    # Return root if lone separator.
    return Directory.new(miqfs.boot_sector) if p == "/" or p == "\\"
		
    # Get an array of directory names, kill off the first (it's always empty).
    names = p.split(/[\\\/]/); names.shift
		
		# Find first cluster of target dir.
		cluster = miqfs.boot_sector.rootCluster
		loop do
			break if names.empty?
			dir = Directory.new(miqfs.boot_sector, cluster)
			de = dir.findEntry(names.shift, Directory::FE_DIR)
			raise "Can't find directory: \'#{p}\'" if de == nil
			cluster = de.firstCluster
		end
		
		# Save cluster in the cache & return a Directory.
		miqfs.dir_cache[p] = cluster
    return Directory.new(miqfs.boot_sector, cluster)
  end
  
  # Wack leading drive leter & colon.
  def unnormalizePath(p)
    return p[1] == 58 ? p[2, p.size] : p
  end
end
