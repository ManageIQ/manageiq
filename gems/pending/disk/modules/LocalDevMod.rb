require 'disk/modules/MiqLargeFile'

module LocalDevMod
  attr_reader :devFile
  attr_accessor :mkfile

  def d_init
    self.diskType = "LocalDev"
    self.blockSize  = 512
    @mkfile     = nil
    dev       = dInfo.localDev || dInfo.fileName
    @devFile    = dev
    @devFile += @partNum.to_s if @partNum != 0

    #
    # Set fileName after the disk probe has determined that this is a local device.
    # fileName can then be used as a common reference for debugging, etc.
    #
    dInfo.fileName   = dev
    dInfo.mountMode  = "r"

    @rawDisk_file     = MiqLargeFile.open(dev, "r")
  end

  def getBase
    self
  end

  def d_read(pos, len, offset       = 0)
    pos += @dInfo.offset if @dInfo.offset
    @rawDisk_file.seek(pos - offset, IO::SEEK_SET)
    @rawDisk_file.read(len)
  end

  def d_write(_pos, _buf, _len, _offset = 0)
    raise "LocalDevMod: write not supported"
  end

  def d_close
    @rawDisk_file.close
  end

  # Disk size in sectors.
  def d_size
    @rawDisk_file.size / @blockSize
  end
end
