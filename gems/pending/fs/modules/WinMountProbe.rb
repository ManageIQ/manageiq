$:.push("#{File.dirname(__FILE__)}/../MiqFS")
$:.push("#{File.dirname(__FILE__)}/../../metadata/util/win32")

require 'MiqFS'
require 'system_path_win'

module WinMountProbe
    
    WIN_FS_TYPES   = [ "FAT32", "NTFS", "ntfs" ]
    
	def WinMountProbe.probe(fs)
		if !WIN_FS_TYPES.include?(fs.fsType)
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

		return false
	end
end
