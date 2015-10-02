# encoding: US-ASCII
module QcowDiskProbe
  QCOW_MAGIC   = "QFI\xfb"
  QCOW_DISK    = "QcowDisk"

  def self.probe(ostruct)
    return nil if ostruct.fileName.nil?

    size  = File.size(ostruct.fileName)
    f     = File.new(ostruct.fileName, "rb")

    rv = doProbe(f)
    f.close

    rv
  end

  def self.probeByDisk(disk)
    doProbe(disk)
  end

  def self.doProbe(io)
    io.seek(0)
    magic = io.read(4)

    return QCOW_DISK if magic == QCOW_MAGIC
    $log.debug "QcowDiskProbe.doProbe: returning nil, #{magic.dump} != #{QCOW_MAGIC.dump}"
    nil
  end

  def self.stackable?
    true
  end
end
