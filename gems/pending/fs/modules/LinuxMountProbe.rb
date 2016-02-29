require 'fs/MiqFS/MiqFS'

module LinuxMountProbe
  LINUX_FS_TYPES   = %w( Ext3 ext3 Ext4 ext4 ReiserFS XFS )
  LINUX_ROOT_DIRS  = ["bin", "dev", "etc", "lib", "proc", "sbin", "usr"]
  LINUX_ROOT_FILES = ["/etc/fstab"]

  def self.probe(fs)
    unless LINUX_FS_TYPES.include?(fs.fsType)
      $log.error "LinuxMountProbe << FALSE because file system (#{fs.fsType}) is not supported" if $log
      return false
    end

    if (fs.dirEntries & LINUX_ROOT_DIRS).length != LINUX_ROOT_DIRS.length
      $log.debug "LinuxMountProbe << FALSE because root directories (#{LINUX_ROOT_DIRS.inspect}) missing in: #{fs.dirEntries.inspect}" if $log
      return false
    end

    LINUX_ROOT_FILES.each do |f|
      unless fs.fileExists?(f)
        $log.error "LinuxMountProbe << FALSE because file #{f} does not exist" if $log
        return false
      end
    end

    $log.debug "LinuxMountProbe << TRUE" if $log
    true
  end
end
