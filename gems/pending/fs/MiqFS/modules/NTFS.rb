require 'rufus/lru'

# NTFS stuff.
$:.push("#{File.dirname(File.expand_path(__FILE__))}/../../ntfs")
require 'NtfsBootSect'

# NTFS file system interface to MiqFS.
module NTFS
  
	# Default index cache size
	DEF_CACHE_SIZE = 50
	
  # Members (these become members of an MiqFS instance).
  attr_accessor :boot_sector, :drive_root, :index_cache, :cache_hits
  
  # Top level file object.
  class FileObject
    
    include NTFS
    attr_reader :path, :din, :data, :miqfs
    # NOTE: miqfs will always be an MiqFS instance.
    
    # fs_fileOpen passes 'self' into .. er, 'this'.
    def initialize(path, miqfs)
      @path = path
      @miqfs = miqfs
    end
    
    def open(mode = "rb")
      # NTFS module methods use miqfs instance accessors to
      # touch @boot_sector, @drive_root, @index_cache and @cache_hits
      # (and any other NTFS members that may come later)
      @din = ifs_getFile(@path, @miqfs)
      raise "File not found: '#{@path}'"    if @din.nil?
      mft_entry = @din.resolve(@miqfs.boot_sector)
      raise "File is directory: '#{@path}'" if @din.isDir?
      @data = mft_entry.attributeData || AttribData.new("", 0)
    end
    
    def seek(offset, method = IO::SEEK_SET)
      @data.seek(offset, method)
    end
  end
  
  # File system interface.
  def fs_init
    self.fsType = "NTFS"
    
    # Initialize Boot Sector
		@dobj.seek(0, IO::SEEK_SET)
    self.boot_sector = BootSect.new(@dobj)
    self.boot_sector.setup
    self.drive_root  = self.boot_sector.rootDir
		
		# Init cache.
    self.index_cache = LruHash.new(DEF_CACHE_SIZE)
    self.cache_hits  = 0
		
		# Expose fsId & volName.
		@fsId, @volName = getVolumeInfo
  end
	
	def getVolumeInfo
	  vi = self.boot_sector.volumeInfo
	  volName = vi["name"]
	  fsId    = vi["objectId"]
		return fsId, volName
	end
	
  # Returns free space on file system in bytes.
	def fs_freeBytes
	  return self.boot_sector.freeBytes
	end

	# In these, p is a path.
  
  # Returns String array of all names, sans path.
  def fs_dirEntries(p)
    # Get path index (directory).
    index = ifs_getDir(p)
    return nil if index == nil
    return index.globNames
  end

	# Returns true if name exists, false if not.
  def fs_fileExists?(p)
    file = ifs_getFile(p)
    return false if file == nil
    true
  end

  # Returns true if name is a regular file.
  # NOTE: If a name isn't a directory, it's always a file - so far...
  # (it could be a reparse point [a.k.a. hard link], but that's for later).
  def fs_fileFile?(p)
    file = ifs_getFile(p)
    return false if file == nil
    file.resolve(self.boot_sector)
    return false if file.isDir?
    true
  end

  # Returns true if name is a directory.
  def fs_fileDirectory?(p)
    file = ifs_getFile(p)
    return false if file == nil
    file.resolve(self.boot_sector)
    return true if file.isDir?
    false
  end
  
  # Returns true if name is a symbolic link.
  def fs_isSymLink?(p)
    return false
  end
  
  # Returns size in bytes.
  def fs_fileSize(p)
    file = ifs_getFile(p)
    return nil if file == nil
    return file.afn.length
  end
	
  # Returns Ruby Time object.
  # NOTE: I *did* find files with 0 time, but they should never appear in this context.
  def fs_fileAtime(p)
    file = ifs_getFile(p)
    return nil if file == nil
    return file.afn.aTime
  end
	
  # Returns Ruby Time object.
  def fs_fileCtime(p)
    file = ifs_getFile(p)
    return nil if file == nil
    return file.afn.cTime
  end

  # Returns Ruby Time object.
  def fs_fileMtime(p)
    file = ifs_getFile(p)
    return nil if file == nil
    return file.afn.mTime
  end

  # In these, fobj is a FileObject, a DIN and AD.
  # AD is not valid until opened. All afn members
  # except permissions can be picked up from afn
  # before resolving data (opening file).
  
  # A FileObject is basically just :din, :data
  
  def fs_fileSize_obj(fobj)
		return 0 if fobj.data.nil?
    fobj.data.length
  end
  
  # Returns a Ruby Time object.
  def fs_fileAtime_obj(fobj)
    fobj.din.afn.aTime
  end

  # Returns a Ruby Time object.
  def fs_fileCtime_obj(fobj)
    fobj.din.afn.cTime
  end

  # Returns a Ruby Time obect.
  def fs_fileMtime_obj(fobj)
    fobj.din.afn.mTime
  end
  
  # File size the faster way.
  def fs_fileSize_obj(fobj)
    fobj.din.afn.length
  end
  
  # New FileObject instance.
  # NOTE: FileObject must have access to NTFS members.
  # This is kind of like a 'skip this' thing. NTFS methods
  # use stuff owned by MiqFS, so this is necessary.
  def fs_fileOpen(p, mode="r")
    fobj = FileObject.new(p, self)
    fobj.open
    return fobj
  end

	# Seek to the requested position
  def fs_fileSeek(fobj, offset, whence)
    fobj.seek(offset, whence)
  end

  # Returns a Ruby String object.
  def fs_fileRead(fobj, len)
		return nil if fobj.data.nil?
    fobj.data.read(len)
  end

  # Unless there's a way to explicitly destroy an object there's nothing to do here.
  def fs_fileClose(fobj)
		fobj = nil
  end
  
  # IFS members: internal file system.
  
  # Return DirectoryIndexNode for a given file or nil if not exist.
  def ifs_getFile(p, miqfs = nil)
    $log.debug "NTFS.ifs_getFile >> p=#{p}" if $log && $log.debug?

    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an NTFS module method, then self owns contained instance members.
    miqfs = self if miqfs.nil?

    # Wack leading drive.
    p = unnormalizePath(p).downcase

    # Get directory & file as separate strings.
    dir = p.split(/[\\\/]/)
    fname = dir[dir.size - 1]
    fname = "." if fname.nil? # Special case: if fname is nil then dir is root.
    dir = dir.size > 2 ? dir[0...dir.size - 1].join('/') : '/'

    # Check for this file in the cache.
    cache_name = "#{dir == '/' ? '' : dir}/#{fname}"
		if miqfs.index_cache.has_key?(cache_name)
			miqfs.cache_hits += 1
      file = miqfs.index_cache[cache_name]
      $log.debug "NTFS.ifs_getFile << (cached) p=#{p} din=#{file}" if $log && $log.debug?
      return file
		end

    # Look for file in dir, but don't error if it doesn't exist.
    # NOTE: if p is a directory that's ok, find it.
    file = nil
    index = ifs_getDir(dir, miqfs)
    unless index.nil?
      $log.debug "NTFS.ifs_getFile -- getting din for #{fname} in <#{index.class.name}>" if $log && $log.debug?
      file = index.find(fname)
    end

    $log.debug "NTFS.ifs_getFile << p=#{p} din=#{file}" if $log && $log.debug?
    return miqfs.index_cache[cache_name] = file
  end

  # Return an index of a path.
  # Raise error if path doesn't exist.
  def ifs_getDir(p, miqfs = nil)
    $log.debug "NTFS.ifs_getDir >> p=#{p}" if $log && $log.debug?

    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an NTFS module method, then self owns contained instance members.
    miqfs = self if miqfs == nil

    # Wack leading drive.
    p = unnormalizePath(p).downcase

    # Get an array of directory names, kill off the first (it's always empty).
    names = p.split(/[\\\/]/)
    names.shift

    # Get the index for this directory
    index = ifs_getIndex(names, miqfs)
    $log.debug "NTFS.ifs_getDir << #{index.nil? ? "Directory not found " : ""}p=#{p}" if $log && $log.debug?
    return index
  end

  # Return DirectoryIndexNode for given directory or nil if not exist.
  def ifs_getIndex(names, miqfs)
    return miqfs.drive_root if names.empty?

    # Check for this path in the cache.
    fname = names.join('/')
		if miqfs.index_cache.has_key?(fname)
			miqfs.cache_hits += 1
      return miqfs.index_cache[fname]
		end

    name = names.pop
    index = ifs_getIndex(names, miqfs)
    return nil if index.nil?

    din = index.find(name)
    return nil if din.nil?

    index = din.resolve(miqfs.boot_sector).indexRoot
    return nil if index.nil?

    return miqfs.index_cache[fname] = index
  end
  
  # Wack leading drive leter & colon.
  def unnormalizePath(p)
    return p[1] == 58 ? p[2, p.size] : p
  end
end
