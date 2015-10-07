require 'util/extensions/miq-string'

require 'stringio'
require 'find'

require 'fs/MiqFS/FsProbe'

class MiqFS
  attr_accessor :fsType, :dobj, :fsId, :volName

  #
  # Class method to instantiate a MiqFS object
  # to handle the file system type detected on
  # the given disk.
  #
  def self.getFS(dobj, probes = nil)
    return(nil)   if dobj.fs == :none
    return(dobj.fs) if dobj.fs

    if probes.nil? && dobj.dInfo.localDev
      require 'fs/modules/NativeFS'
      return(new(NativeFS, dobj)) if NativeFS.supported?(dobj)
      return(nil)
    end

    if (fsm = FsProbe.getFsMod(dobj, probes))
      fs = new(fsm, dobj)
      dobj.fs = fs
      return(fs)
    end
    dobj.fs = :none if probes.nil? # only if we performed a full probe
    (nil)
  end

  def initialize(fsm, dobj)
    extend(fsm)
    @dobj = dobj
    @cwd = "/"
    @fsId = ''
    @volName = ''
    fs_init
    @fsId = @fsId.to_s

    @findEachPrune = false
    @findEachYield = false
  end

  def umount
    fs_umount if self.respond_to?(:fs_umount)
    nil
  end

  # Return free space in file system.
  def freeBytes
    fs_freeBytes
  end

  #
  # Directory instance methods
  #

  def chdir(dir)
    twd = normalizePath(dir)
    raise "Directory not found: #{twd}" unless fileDirectory?(twd)
    @cwd = twd
  end

  def dirEntries(*dir)
    fs_dirEntries(optDir(dir))
  end

  def dirForeach(*dir, &block)
    ents = fs_dirEntries(optDir(dir))
    ents.each { |e| block.call(e) }
  end

  def pwd
    @cwd
  end

  GLOB_CHARS = '*?[{'
  def isGlob?(str)
    str.count(GLOB_CHARS) != 0
  end

  def dirGlob(glb, *flags, &block)
    return([glb]) unless isGlob?(glb)

    if glb[0, 1] == '/'
      dir = '/'
      glb = glb[1..-1]
    else
      dir = @cwd
    end

    matches = doGlob(glb.split('/'), dir, flags)
    return(matches) unless block_given?

    matches.each do |e|
      block.call(e)
    end
    (false)
  end

  def doGlob(glbArr, dir, flags)
    return [] if !glbArr || glbArr.length == 0

    retArr = []
    glb = glbArr[0]

    dirForeach(dir) do |e|
      if flags.length == 0
        match = File.fnmatch(glb, e)
      else
        match = File.fnmatch(glb, e, flags)
      end
      if match
        if glbArr.length == 1
          retArr << File.join(dir, e)
        else
          next unless fileDirectory?(nf = File.join(dir, e))
          retArr.concat(doGlob(glbArr[1..-1], nf, flags))
        end
      end
    end
    (retArr)
  end

  def dirMkdir(dir)
    fs_dirMkdir(normalizePath(dir))
  end

  def dirRmdir(dir)
    fs_dirRmdir(normalizePath(dir))
  end

  #
  # File instance methods
  #

  def fileExists?(f)
    fs_fileExists?(normalizePath(f))
  end

  def fileFile?(f)
    fs_fileFile?(normalizePath(f))
  end

  def fileDirectory?(f)
    fs_fileDirectory?(normalizePath(f))
  end

  def fileSymLink?(f)
    p = normalizePath(f)
    (fs_isSymLink?(p))
  end

  def fileOpen(f, mode = "r", &block)
    fpf = normalizePath(f)
    fo = fileOpenCommon(fpf, mode, &block)
    (fo)
  end

  def fileOpenLink(f, mode = "r", &block)
    fpf = normalizePath(f)
    fileOpenCommon(fpf, mode, &block)
  end

  def fileOpenCommon(fpf, mode = "r", &block)
    fobj = fs_fileOpen(fpf, mode)
    return(nil) unless fobj
    fo = MiqFile.new(self, fobj)

    if self.respond_to?(:fs_fileObjExtend)
      fo = fs_fileObjExtend(fo)
    end

    if block_given?
      begin
        rv = block.call(fo)
        return(rv)
      ensure
        fileClose(fo)
      end
    end
    (fo)
  end

  def fileClose(mfobj)
    fs_fileClose(mfobj.fobj)
  end

  def fileDelete(f)
    fs_fileDelete(normalizePath(f))
  end

  def fileSize(f)
    fs_fileSize(normalizePath(f))
  end

  def fileBasename(f, *sfx)
    return(File.basename(f)) if sfx.length == 0
    (File.basename(f, sfx[0]))
  end

  def fileDirname(f)
    File.dirname(f)
  end

  def fileExtname(f)
    File.extname(f)
  end

  def fileFnmatch(glb, pth, *flags)
    return(File.fnmatch(glb, pth)) if flags.length == 0
    (File.fnmatch(glb, pth, flags))
  end

  def fileAtime(f)
    fs_fileAtime(normalizePath(f))
  end

  def fileCtime(f)
    fs_fileCtime(normalizePath(f))
  end

  def fileMtime(f)
    fs_fileMtime(normalizePath(f))
  end

  def fileAtime_obj(fo)
    fs_fileAtime_obj(fo)
  end

  def fileCtime_obj(fo)
    fs_fileCtime_obj(fo)
  end

  def fileMtime_obj(fo)
    fs_fileMtime_obj(fo)
  end

  def find(dir, depth = nil, level = 0)
    return if depth && level > depth
    foundFiles = []

    dirEntries = self.dirEntries(dir)
    dirEntries.each do |de|
      next if de == '.' || de == '..'
      fp = File.join(dir, de)
      foundFiles << fp
      foundFiles.concat(find(fp, depth, level + 1)) if self.fileDirectory?(fp)
    end
    (foundFiles)
  end

  def findEach(dir, depth = nil, level = 0, &block)
    return if depth && level > depth
    return unless (dirEntries = self.dirEntries(dir))
    dirEntries.each do |de|
      next if de == '.' || de == '..'
      fp = File.join(dir, de)
      @findEachYield = true
      begin
        yield(fp)
      ensure
        @findEachYield = false
      end
      findEach(fp, depth, level + 1, &block) if self.fileDirectory?(fp) && !@findEachPrune
      @findEachPrune = false
    end
  end

  def findEachPrune
    raise "MiqFS.findEachPrune: findEach not in progress" unless @findEachYield
    @findEachPrune = true
  end

  def rmBranch(dir)
    raise "rmBranch: #{dir} does not exist"   unless self.fileExists?(dir)
    raise "rmBranch: #{dir} is not a directory" unless self.fileDirectory?(dir)

    dirEntries = self.dirEntries(dir)

    dirEntries.each do |de|
      next if de == '.' || de == '..'
      fp = File.join(dir, de)
      if self.fileDirectory?(fp)
        rmBranch(fp)
      else
        fileDelete(fp)
      end
    end if dirEntries
    dirRmdir(dir)
  end

  #
  # Copy files and directories from the VM to the host.
  #
  # FILE -> FILE
  # FILE -> DIR
  # DIR  -> DIR (recursive = true)
  #
  def copyOut(from, to, recursive = false)
    allTargets = []
    from = [from] unless from.kind_of?(Array)
    from.each { |t| allTargets.concat(dirGlob(t)) }

    raise "copyOut: no source files matched" if allTargets.length == 0
    if allTargets.length > 1 || recursive
      raise "copyOut: destination directory does not exist" unless File.exist?(to)
      raise "copyOut: destination must be a directory for multi-file copy" unless File.directory?(to)
    end

    allTargets.each do |f|
      #
      # Copy plain files.
      #
      if fileFile?(f)
        if fileDirectory?(to)
          tf = File.join(to, File.basename(f))
        else
          tf = to
        end
        copyOutSingle(f, tf)
        next
      end

      #
      # If the recursive flag is not set, skip directories.
      #
      next unless recursive

      #
      # Recursively copy directory sub-tree.
      #
      owd = @cwd
      chdir(f)
      td = File.join(to, f)
      Dir.mkdir(td) unless File.exist?(td)
      findEach('.') do |ff|
        tf = File.join(td, ff)
        if fileDirectory?(ff)
          Dir.mkdir(tf)
        elsif fileFile?(ff)
          copyOutSingle(ff, tf)
        end
      end # findEach
      chdir(owd)
    end # allTargets.each
  end

  def copyOutSingle(ff, tf)
    fileOpen(ff) do |ffo|
      tfo = File.new(tf, "wb")
      while (buf = ffo.read(1024))
        tfo.write(buf)
      end
      tfo.close
    end
  end

  #
  # Copy files and directories from the host to the VM.
  #
  # FILE -> FILE
  # FILE -> DIR
  # DIR  -> DIR (recursive = true)
  #
  def copyIn(from, to, recursive = false)
    allTargets = []
    from = [from] unless from.kind_of?(Array)
    from.each { |t| allTargets.concat(Dir.glob(t)) }

    raise "copyIn: no source files matched" if allTargets.length == 0
    if allTargets.length > 1 || recursive
      raise "copyIn: destination directory does not exist" unless self.fileExists?(to)
      raise "copyIn: destination must be a directory for multi-file copy" unless self.fileDirectory?(to)
    end

    allTargets.each do |f|
      #
      # Copy plain files.
      #
      if File.file?(f)
        if self.fileDirectory?(to)
          tf = File.join(to, File.basename(f))
        else
          tf = to
        end
        copyInSingle(f, tf)
        next
      end

      #
      # If the recursive flag is not set, skip directories.
      #
      next unless recursive

      #
      # Recursively copy directory sub-tree.
      #
      owd = Dir.pwd
      Dir.chdir(f)
      td = File.join(to, f)
      dirMkdir(td) unless self.fileExists?(td)
      Find.find('.') do |ff|
        tf = File.join(td, ff)
        if File.directory?(ff)
          dirMkdir(tf) unless self.fileExists?(tf)
        elsif File.file?(ff)
          copyInSingle(ff, tf)
        end
      end # Find.find
      Dir.chdir(owd)
    end # allTargets.each
  end

  def copyInSingle(ff, tf)
    File.open(ff) do |ffo|
      tfo = fileOpen(tf, "wb")
      while (buf = ffo.read(1024))
        tfo.write(buf)
      end
      tfo.close
    end
  end

  def normalizePath(p)
    # At the base FS level, we should never see a drive letter.
    np = File.expand_path(p, @cwd).gsub(/^[a-zA-Z]:/, "")
    # puts "MiqFS::normalizePath: p = #{p}, np = #{np}"
    (np)
  end

  def expandPath(path, dir)
    if path[0, 1] == '/'
      tPath = path
    else
      tPath = File.join(dir, path)
    end

    tpa = tPath.slice('/')
    return(tPath) if tpa.empty?

    rpa = []
    tpa.each do |d|
      case d
      when ".." then rpa.pop
      when "."  then next
      when ""   then next
      else rpa << d
      end
    end
    ("/" + rpa.join("/"))
  end

  def optDir(dir)
    return(@cwd) if dir.length == 0
    (normalizePath(dir[0]))
  end

  #
  # Overridden by fs module if the fs supports symbolic links.
  #
  def fs_supportsSymLinks
    false
  end

  def fs_isSymLink?(_f)
    false
  end

  private :normalizePath, :optDir, :fileOpenCommon
end

class MiqFile
  attr_accessor :fs, :fobj

  def initialize(fs, fobj)
    @fs = fs
    @fobj = fobj
  end

  def seek(amt, whence = IO::SEEK_SET)
    @fs.fs_fileSeek(@fobj, amt, whence)
  end

  def read(len = -1)
    return(@fs.fs_fileRead(@fobj, len)) if len >= 0
    (@fs.fs_fileRead(@fobj, size))
  end

  def write(buf, len = buf.length)
    return(@fs.fs_fileWrite(@fobj, buf, len)) if len >= 0
  end

  def close
    @fs.fs_fileClose(@fobj)
  end

  def size
    @fs.fs_fileSize_obj(@fobj)
  end

  def atime
    @fs.fileAtime_obj(@fobj)
  end

  def ctime
    @fs.fileCtime_obj(@fobj)
  end

  def mtime
    @fs.fileMtime_obj(@fobj)
  end
end
