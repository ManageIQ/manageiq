require 'rufus/lru'

# Iso9660 stuff.
$:.push("#{File.dirname(__FILE__)}/../../iso9660")
require 'Iso9660BootSector'
require 'Iso9660DirectoryEntry'
require 'Iso9660Directory'
require 'Iso9660FileData'

module Iso9660
	
	# Default cache size.
	DEF_CACHE_SIZE = 50
	
	PRIMARY_SECTOR	= 16
	JOLIET_SECTOR		= 17
	SECTOR_SIZE			= 2048
  
	# Members (these become members of an MiqFS instance).
  attr_accessor :boot_sector, :drive_root, :dir_cache, :cache_hits
	
  # Top level file object.
  class FileObject
    
    include Iso9660
    attr_reader :path, :de, :data, :miqfs
    # NOTE: miqfs will always be an MiqFS instance.
    
    # fs_fileOpen passes 'self' into .. er, 'this'.
    def initialize(path, miqfs)
      @path = path
      @miqfs = miqfs
    end
    
    def open(mode = "r")
      # Iso9660 module methods use miqfs instance accessors to touch @boot_sector.
			@mode = mode.downcase
			@de = ifs_getFile(@path, @miqfs)
			if @de != nil
				raise "File is directory: '#{@path}'" if @de.isDir?
			end
			if mode.include?("r")
				raise "File not found: '#{@path}'" if @de == nil
				@data = FileData.new(@de, @miqfs.boot_sector)
			end
    end
  end
	
	def fs_init
		self.fsType = "ISO9660"
		
		# Start by looking for a Joliet volume descriptor after the primary descriptor.
		found_joliet = false
		@dobj.seek(JOLIET_SECTOR * SECTOR_SIZE)
		begin
			@boot_sector = BootSector.new(@dobj, true)
			found_joliet = true
		rescue
		end
		
		# If Joliet wasn't found, look for a primary descriptor.
		if not found_joliet
			found_primary = false
			@dobj.seek(PRIMARY_SECTOR * SECTOR_SIZE)
			loop do
				begin
					@boot_sector = BootSector.new(@dobj)
					found_primary = true
					break
				rescue
				end
			end
			raise "Iso9660#fs_init couldn't find primary descriptor." if not found_primary
		end
		
		# Set volume id.
		#@fsId = ... hmmm, how to get the serial number.
		@volName = @boot_sector.volName
		
		# Init cache & root.
		self.dir_cache = LruHash.new(DEF_CACHE_SIZE)
		self.cache_hits = 0
		de = DirectoryEntry.new(@boot_sector.rootEntry, @boot_sector.suff)
		self.drive_root = Directory.new(@boot_sector, de)
	end
	
	# Returns free space on file system in bytes.
	def fs_freeBytes
		return 0
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
	
	# These two are not implemented.
	def fs_dirMkdir(p)
		raise "Write functionality is not supported on Iso9660."
	end
	
	# Remove a directory.
	def fs_dirRmdir(p)
		raise "Write functionality is not supported on Iso9660."
	end
	
	#
	# File instance methods.
	#
	
	# Returns true if name exists, false if not.
  def fs_fileExists?(p)
    de = ifs_getFile(p)
    return false if de == nil
    return true
  end
	
  # Returns true if name is a regular file.
  def fs_fileFile?(p)
    de = ifs_getFile(p)
    return false if de == nil
    return de.isFile?
  end
	
  # Returns true if name is a directory.
  def fs_fileDirectory?(p)
    de = ifs_getFile(p)
    return false if de == nil
    return de.isDir?
  end
	
  # Returns size in bytes.
  def fs_fileSize(p)
    de = ifs_getFile(p)
    return nil if de == nil
		return de.fileSize
  end
	
	# Delete file.
	def fs_fileDelete(p)
		raise "Write functionality is not supported on Iso9660."
	end
	
  # Returns Ruby Time object.
  def fs_fileAtime(p)
    de = ifs_getFile(p)
    return nil if de == nil
		return de.date
  end
	
  # Returns Ruby Time object.
  def fs_fileCtime(p)
    de = ifs_getFile(p)
    return nil if de == nil
    return de.date
  end
	
  # Returns Ruby Time object.
  def fs_fileMtime(p)
    de = ifs_getFile(p)
    return nil if de == nil
    return de.date
  end
	
  # Return true if p is a path to a symbolic link.
  def fs_isSymLink?(p)
    de = ifs_getFile(p)
    return false if de == nil
    return de.isSymLink?
  end
  
	# In these, fobj is a FileObject.
  def fs_fileSize_obj(fobj)
    fobj.de.fileSize
  end
  
  # Returns a Ruby Time object.
  def fs_fileAtime_obj(fobj)
    fobj.de.date
  end
	
  # Returns a Ruby Time object.
  def fs_fileCtime_obj(fobj)
    fobj.de.date
  end
	
  # Returns a Ruby Time obect.
  def fs_fileMtime_obj(fobj)
    fobj.de.date
  end
  
  # New FileObject instance.
  # NOTE: FileObject must have access to Iso9660 members.
  # This is kind of like a 'skip this' thing. Ext3 methods
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
		raise "Write functionality is not supported on Iso9660."
	end
	
  # Destroy file object.
  def fs_fileClose(fobj)
		fobj = nil
  end
  
  # IFS members: internal file system.
  
  # Return a DirectoryEntry for a given file or nil if not exist.
  def ifs_getFile(p, miqfs = nil)
    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an Ext3 module method, then self owns contained instance members.
    miqfs = self if miqfs == nil
    
    # Preprocess path.
    p = unnormalizePath(p)
    dir, fil = File.split(p)
		# Fix for FB#835: if fil == root then fil needs to be "."
		fil = "." if fil == "/" or fil == "\\"
    
    # Look for file in dir, but don't barf if it doesn't exist.
    # NOTE: if p is a directory that's ok, find it.
    begin
      dirObj = ifs_getDir(dir, miqfs)
      return nil if dirObj == nil
      dirEnt = dirObj.findEntry(fil)
      return nil if dirEnt == nil      
    rescue RuntimeError
			return nil
    end
    return dirEnt
  end
  
	# Return a Directory object for a path.
  # Raise error if path doesn't exist.
  def ifs_getDir(p, miqfs = nil)
    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an Ext3 module method, then self owns contained instance members.
    miqfs = self if miqfs == nil
    
    # Wack leading drive.
    p = unnormalizePath(p)
		
		# Check for this path in the cache.
		if miqfs.dir_cache.has_key?(p)
			miqfs.cache_hits += 1
			return Directory.new(miqfs.boot_sector, DirectoryEntry.new(miqfs.dir_cache[p], miqfs.boot_sector.suff))
		end
		
    # Return root if lone separator.
    return miqfs.drive_root if p == "/" or p == "\\"
		
    # Get an array of directory names, kill off the first (it's always empty).
    names = p.split(/[\\\/]/); names.shift
		
		# Find target dir.
		de = miqfs.drive_root.myEnt
		loop do
			break if names.empty?
			dir = Directory.new(miqfs.boot_sector, de)
			de = dir.findEntry(names.shift, Directory::FE_DIR)
			raise "Can't find directory: \'#{p}\'" if de == nil
		end
		
		# Save dir ent in the cache & return a Directory.
		# NOTE: This stores only the directory entry data string - not the whole object.
		miqfs.dir_cache[p] = de.myEnt
    return Directory.new(miqfs.boot_sector, de)
  end
  
  # Wack leading drive leter & colon.
  def unnormalizePath(p)
    return p[1] == 58 ? p[2, p.size] : p
  end

end #module
