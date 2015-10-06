require 'sys-uname'
require 'fs/MiqFS/MiqFS'
require 'metadata/util/win32/boot_info_win'

module WinMount
  def fs_init
    @guestOS = "Windows"

    @rootFS = MiqFS.getFS(@rootVolume)
    raise MiqException::MiqVmMountError, "WinMount: could not mount root volume" unless @rootFS
    @allFileSystems << @rootFS

    #
    # Build volume ID to drive letter mapping.
    #
    idToDriveLetter = {}
    drives = Win32::SystemPath.driveAssignment(@rootFS)
    if drives.empty?
      idToDriveLetter["#{@rootVolume.diskSig}-#{@rootVolume.lbaStart}"] = "C:"
      $log.debug "WinMount.fs_init: [@rootVolume.diskSig}-@rootVolume.lbaStart] = [#{@rootVolume.diskSig}-#{@rootVolume.lbaStart}]"
    else
      drives.each do |da|
        idToDriveLetter["#{da[:serial_num]}-#{da[:starting_sector]}"] = da[:name].upcase
        $log.debug "WinMount.fs_init: [da[:serial_num]}-da[:starting_sector] = [#{da[:serial_num]}-#{da[:starting_sector]}]"
      end
    end

    #
    # Build drive letter to file system mapping.
    #
    @driveToFS = {}
    if (lvObj = @rootVolume.dInfo.lvObj) && lvObj.driveHint
      key = lvObj.lvId
      @rootDriveLetter = lvObj.driveHint
      $log.debug "WinMount.fs_init: @rootDriveLetter = lvObj.driveHint = #{@rootDriveLetter}"
    else
      key = "#{@rootVolume.diskSig}-#{@rootVolume.lbaStart}"
      @rootDriveLetter = idToDriveLetter[key]
      $log.debug "WinMount.fs_init: @rootDriveLetter = idToDriveLetter[#{key}] = #{@rootDriveLetter}"
    end
    raise MiqException::MiqVmMountError, "Could not determine root drive letter." unless @rootDriveLetter
    @driveToFS[@rootDriveLetter] = @rootFS
    saveFs(@rootFS, @rootDriveLetter, key)

    @osNames = {}
    @volumes.each do |v|
      if (lvObj = v.dInfo.lvObj) && lvObj.driveHint
        key = lvObj.lvId
        dl = lvObj.driveHint
      else
        key = "#{v.diskSig}-#{v.lbaStart}"
        next unless (dl = idToDriveLetter[key])
      end
      @osNames[v.dInfo.hardwareId + ':' + v.partNum.to_s] = dl
      next if v == @rootVolume
      next unless (fs = MiqFS.getFS(v))
      @allFileSystems << fs
      @driveToFS[dl] = fs
      saveFs(fs, dl, key)
    end

    @cwd = "#{@rootDriveLetter}/"
  end # def fs_init

  private

  def normalizePath(p)
    if Sys::Platform::OS == :unix
      return p if p[1..1] == ':' # fully qualified path
      p = p.slice(1..-1) if p[0, 1] == '/'
      # On Linux, protect the drive letter with a '/', then remove it.
      return File.expand_path(p, '/' + @cwd).slice(1..-1)
    end
    File.expand_path(p, @cwd)
  end

  #
  # Mount indirection look up.
  # Given a path, return its corresponding file system
  # and the part of the path relative to that file system.
  #
  def getFsPath(path)
    if path.kind_of? Array
      if path.length == 0
        localPath = @cwd.dup
      else
        localPath = normalizePath(path[0].dup)
      end
    else
      localPath = normalizePath(path.dup)
    end

    dl = localPath.slice!(0..1).upcase
    raise MiqException::MiqVmMountError, "Unknown drive letter - #{dl}" unless (fs = @driveToFS[dl])
    return fs, localPath
  end
end # module WinMount
