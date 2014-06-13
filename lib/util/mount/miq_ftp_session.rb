# FTP is not quite the same as the nfs/smb sessions in that you copy/remove files
# via an ftp handle whereas the nfs/smb logic uses mount to mount the remote filesystem
# and does the copy/remove directly on the mounted volume.  Will need to remove the
# logfile logic from the LogFile _ftp methods in order to refactor it into a standalone class
class MiqFtpSession
end
