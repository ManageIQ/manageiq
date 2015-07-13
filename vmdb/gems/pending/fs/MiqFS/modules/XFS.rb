require 'rufus/lru'

# XFS stuff.
$LOAD_PATH.push("#{File.dirname(File.expand_path(__FILE__))}/../../xfs")
require 'superblock'
# require 'xfs_directory_entry'
require 'directory'

# XFS file system interface to MiqFS.
module XFS
  # Default directory cache size.
  DEF_CACHE_SIZE = 500

  # Members (these become members of an MiqFS instance).
  attr_accessor :superblock, :rootDir, :entry_cache, :dir_cache, :cache_hits

  # Top level file object.
  class FileObject
    include XFS
    attr_reader :path, :de, :inode, :miqfs
    # NOTE: miqfs will always be an MiqFS instance.

    # fs_fileOpen passes 'self' into .. er, 'this'.
    def initialize(path, miqfs)
      @path = path
      @miqfs = miqfs
    end

    def open(mode = "r")
      # XFS module methods use miqfs instance accessors to touch @boot_sector.
      @mode = mode.downcase
      @de = ifs_getFile(@path, @miqfs)
      raise "File is directory: '#{@path}'" if  @de && @de.directory?

      if mode.include?("r")
        raise "File not found: '#{@path}'" if @de.nil?
        @inode = @miqfs.superblock.get_inode(@de.inode)
      end
    end
  end

  # File system interface.
  def fs_init
    self.fsType = "XFS"

    # Initialize bs & read root dir.
    @dobj.seek(0, IO::SEEK_SET)
    self.superblock  = Superblock.new(@dobj)
    @fs_id           = superblock.filesystem_id.to_s
    @volName         = superblock.volume_name
    self.rootDir     = Directory.new(superblock, superblock.root_inode)
    self.entry_cache = LruHash.new(DEF_CACHE_SIZE)
    self.dir_cache   = LruHash.new(DEF_CACHE_SIZE)
    self.cache_hits  = 0
  end

  # Returns free space on file system in bytes.
  def fs_freeBytes
    @superblock.free_bytes
  end

  #
  # Directory instance methods.
  #

  # Returns String array of all names, sans path.
  # TODO
  def fs_dirEntries(p)
    # Get path directory.
    dir = ifs_getDir(p)
    return nil if dir.nil?
    dir.glob_names
  end

  # Make a directory. Parent must exist.
  # TODO
  def fs_dirMkdir(_p)
    raise "Write functionality is not yet supported on XFS."
  end

  # Remove a directory.
  # TODO
  def fs_dirRmdir(_p)
    raise "Write functionality is not yet supported on XFS."
  end

  #
  # File instance methods.
  #

  # Returns true if name exists, false if not.
  def fs_fileExists?(p)
    de = ifs_getFile(p)
    return false if de.nil?
    true
  end

  # Returns true if name is a regular file.
  def fs_fileFile?(p)
    de = ifs_getFile(p)
    return false if de.nil?
    de.file_type == Inode::FT_FILE
  end

  # Returns true if name is a directory.
  def fs_fileDirectory?(p)
    de = ifs_getFile(p)
    return false if de.nil?
    de.file_type == Inode::FT_DIRECTORY
  end

  # Returns size in bytes.
  def fs_fileSize(p)
    de = ifs_getFile(p)
    return nil if de.nil?
    @superblock.get_inode(de.inode).length
  end

  # Delete file.
  def fs_fileDelete(_p)
    raise "Write functionality is not yet supported on XFS."
  end

  # Returns Ruby Time object.
  def fs_fileAtime(p)
    de = ifs_getFile(p)
    return nil if de.nil?
    @superblock.get_inode(de.inode).aTime
  end

  # Returns Ruby Time object.
  def fs_fileCtime(p)
    de = ifs_getFile(p)
    return nil if de.nil?
    @superblock.get_inode(de.inode).cTime
  end

  # Returns Ruby Time object.
  def fs_fileMtime(p)
    de = ifs_getFile(p)
    return nil if de.nil?
    @superblock.get_inode(de.inode).mTime
  end

  # Return true if p is a path to a symbolic link.
  def fs_isSymLink?(p)
    de = ifs_getFile(p)
    return false if de.nil?
    de.symlink?
  end
  # In these, fobj is a FileObject.

  def fs_fileSize_obj(fobj)
    fobj.inode.length
  end

  # Returns a Ruby Time object.
  def fs_fileAtime_obj(fobj)
    fobj.inode.access_time
  end

  # Returns a Ruby Time object.
  def fs_fileCtime_obj(fobj)
    fobj.inode.create_time
  end

  # Returns a Ruby Time obect.
  def fs_fileMtime_obj(fobj)
    fobj.inode.modification_time
  end

  # New FileObject instance.
  # NOTE: FileObject must have access to XFS members.
  # This is kind of like a 'skip this' thing. XFS methods
  # use stuff owned by MiqFS, so this is necessary.
  def fs_fileOpen(p, mode = "r")
    fobj = FileObject.new(p, self)
    fobj.open(mode)
    fobj
  end

  # Returns current file position.
  def fs_fileSeek(fobj, offset, whence)
    fobj.inode.seek(offset, whence)
  end

  # Returns a Ruby String object.
  def fs_fileRead(fobj, len)
    fobj.inode.read(len)
  end

  def fs_fileWrite(_fobj, _buf, _len)
    raise "Write functionality is not yet supported on XFS."
  end

  # Write changes & destroy.
  def fs_fileClose(fobj)
    # TODO: unrem when write is supported.
    # fobj.inode.close
    fobj.inode.rewind
    nil
  end

  # IFS members: internal file system.

  # Return a DirectoryEntry for a given file or nil if not exist.
  def ifs_getFile(p, miqfs = nil)
    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an XFS module method, then self owns contained instance members.
    miqfs = self if miqfs.nil?

    # Preprocess path.
    p = unnormalizePath(p)
    dir, fname = File.split(p)
    # Fix for FB#835: if fil == root then fil needs to be "."
    fname = "." if fname == "/" || fname == "\\"

    # Check for this file in the cache.
    cache_name = "#{dir == '/' ? '' : dir}/#{fname}"
    if miqfs.entry_cache.key?(cache_name)
      miqfs.cache_hits += 1
      return miqfs.entry_cache[cache_name]
    end

    # Look for file in dir, but don't error if it doesn't exist.
    # NOTE: if p is a directory that's ok, find it.
    begin
      directory_object = ifs_getDir(dir, miqfs)
      directory_entry = directory_object.nil? ? nil : directory_object.find_entry(fname)
    rescue RuntimeError
      directory_entry = nil
    end

    miqfs.entry_cache[cache_name] = directory_entry
  end

  # Create a directory entry.
  def ifs_putFile(_p, _miqfs = nil)
    raise "Write functionality is not yet supported on XFS."
    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an XFS module method, then self owns contained instance members.
    # miqfs = self if miqfs.nil?

    # Preprocess path.
    # p = unnormalizePath(p)
    # dir, fil = File.split(p)

    # Parent directory must exist.
    # dirObj = ifs_getDir(dir, miqfs)
    # return nil if dir.nil?
    # dirObj.createFile(fil)
  end

  # Return a Directory object for a path.
  # Raise error if path doesn't exist.
  def ifs_getDir(p, miqfs = nil)
    # If this is being called from a FileObject instance, then MiqFS owns contained instance members.
    # If this is being called from an XFS module method, then self owns contained instance members.
    miqfs = self if miqfs.nil?

    # Wack leading drive.
    p = unnormalizePath(p)

    # Get an array of directory names, kill off the first (it's always empty).
    names = p.split(/[\\\/]/)
    names.shift

    dir = ifs_getDirR(names, miqfs)
    raise "Directory '#{p}' not found" if dir.nil?
    dir
  end

  # Return Directory recursively for given directory or nil if not exist.
  def ifs_getDirR(names, miqfs)
    return miqfs.rootDir if names.empty?

    # Check for this path in the cache.
    fname = names.join('/')
    if miqfs.dir_cache.key?(fname)
      miqfs.cache_hits += 1
      return miqfs.dir_cache[fname]
    end

    name = names.pop
    pdir = ifs_getDirR(names, miqfs)
    return nil if pdir.nil?

    de = pdir.find_entry(name, Inode::FT_DIRECTORY)
    return nil if de.nil?
    miqfs.entry_cache[fname] = de

    dir = Directory.new(miqfs.superblock, de.inode)
    return nil if dir.nil?

    miqfs.dir_cache[fname] = dir
  end

  # Wack leading drive letter & colon.
  def unnormalizePath(p)
    p[1] == 58 ? p[2, p.size] : p
  end
end
