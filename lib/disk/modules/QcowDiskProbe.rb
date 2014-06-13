module QcowDiskProbe
  QCOW_MAGIC   = "QFI\xfb"
  QCOW_DISK    = "QcowDisk"

  def QcowDiskProbe.probe(ostruct)
    return nil if ostruct.fileName.nil?

    size  = File.size(ostruct.fileName)
    f     = File.new(ostruct.fileName, "rb")

    rv = doProbe(f)
    f.close

    return rv
  end

  def QcowDiskProbe.probeByDisk(disk)
    doProbe(disk)
  end

  def QcowDiskProbe.doProbe(io)
    io.seek(0)
    magic = io.read(4)

    return QCOW_DISK if magic == QCOW_MAGIC
    $log.debug "QcowDiskProbe.doProbe: returning nil, #{magic.dump} != #{QCOW_MAGIC.dump}"
    return nil
  end

  def QcowDiskProbe.stackable?
    true
  end
end
