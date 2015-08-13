require 'MiqVm/MiqVm'

class MiqRhevmVm < MiqVm
  RHEV_NFS_UID = 36

  def openDisks(diskFiles)
    if @ost.nfs_mount
      $log.debug "MiqRhevmVm#openDisks: setting euid = #{RHEV_NFS_UID}"
      orig_uid = Process::UID.eid
      Process::UID.grant_privilege(RHEV_NFS_UID)
    end
    rv = super
    if @ost.nfs_mount
      $log.debug "MiqRhevmVm#openDisks: resetting euid = #{orig_uid}"
      Process::UID.grant_privilege(orig_uid)
    end
    rv
  end
end
