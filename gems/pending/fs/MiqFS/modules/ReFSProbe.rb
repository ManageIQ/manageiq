module ReFSProbe
  FS_SIGNATURE  = [0x00, 0x00, 0x00, 0x52, 0x65, 0x46, 0x53, 0x00] # ...ReFS.

  def self.probe(dobj)
    $log.debug "ReFSProbe >> dobj=#{dobj}"  if $log
    return false  unless dobj.kind_of?(MiqDisk)

    dobj.seek(0, IO::SEEK_SET)
    magic = dobj.read(FS_SIGNATURE.size).unpack('C*')

    # Check for ReFS signature
    raise "ReFS is Not Supported" if magic == FS_SIGNATURE

    # No ReFS
    false
  end
end
