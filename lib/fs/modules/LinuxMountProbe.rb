$:.push("#{File.dirname(__FILE__)}/../MiqFS")

require 'MiqFS'

module LinuxMountProbe
    
	LINUX_FS_TYPES   = [ "Ext3", "ext3", "Ext4", "ext4", "ReiserFS" ]
	LINUX_ROOT_DIRS  = [ "bin", "dev", "etc", "lib", "proc", "sbin", "usr" ]
	LINUX_ROOT_FILES = [ "/etc/fstab" ]
    
	def LinuxMountProbe.probe(fs)
		if !LINUX_FS_TYPES.include?(fs.fsType)
			$log.debug "LinuxMountProbe << FALSE because file system (#{fs.fsType}) is not supported" if $log
			return false
 		end
      
		if (fs.dirEntries & LINUX_ROOT_DIRS).length != LINUX_ROOT_DIRS.length
			$log.debug "LinuxMountProbe << FALSE because root directories (#{LINUX_ROOT_DIRS.inspect}) missing in: #{fs.dirEntries.inspect}" if $log
			return false
		end
      
		LINUX_ROOT_FILES.each do |f|
			if !fs.fileExists?(f)
				$log.debug "LinuxMountProbe << FALSE because file #{f} does not exist" if $log
				return false 
			end
		end
    
		$log.debug "LinuxMountProbe << TRUE" if $log
		return true
	end
  
end
