require 'fs/MiqFS/MiqFS'
require 'metadata/util/win32/system_path_win'

module WinMountProbe
  WIN_FS_TYPES   = ["FAT32", "NTFS", "ntfs"]

  def self.probe(fs)
    unless WIN_FS_TYPES.include?(fs.fsType)
      $log.debug "WinMountProbe << FALSE because file system (#{fs.fsType}) is not supported" if $log
      return false
    end

    begin
      si = Win32::SystemPath.systemIdentifier(fs)
      # This method will raise an error if it does not find the file system boot markers
      Win32::SystemPath.systemRoot(fs, si)
      return true
    rescue
      $log.debug "WinMountProbe << FALSE because #{$!} was found" if $log
    end

    false
  end
end
