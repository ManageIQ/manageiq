require 'VixDiskLib/VixDiskLib'

module VixDiskMod
  def d_init
    self.diskType = "VixDisk"
    @vdi = dInfo.vixDiskInfo
    @connection = @vdi[:connection]

    if dInfo.mountMode.nil? || dInfo.mountMode == "r"
      dInfo.mountMode = "r"
      fileMode = VixDiskLib::VIXDISKLIB_FLAG_OPEN_READ_ONLY
    elsif dInfo.mountMode == "rw"
      fileMode = 0
    else
      raise "Unrecognized mountMode: #{dInfo.mountMode}"
    end

    dInfo.fileName = @vdi[:fileName]
    unless (@diskObj = dInfo.vixDiskObj)
      @diskObj = @connection.getDisk(@vdi[:fileName], fileMode)
      dInfo.vixDiskObj = @diskObj
    end
    self.blockSize = @diskObj.sectorSize
  end

  def getBase
    self
  end

  def d_read(pos, len)
    pos += @dInfo.offset if @dInfo.offset
    @diskObj.read(pos, len)
  end

  def d_write(pos, buf, len)
    pos += @dInfo.offset if @dInfo.offset
    @diskObj.write(pos, buf, len)
  end

  def d_close
    if @partNum == 0
      $log.debug "VixDiskMod: closing disk #{@dInfo.fileName}" if $log
      $log.debug "VixDiskMod: closing base VdlDisk <#{@diskObj.ssId}>" if $log
      @diskObj.close
    else
      $log.debug "VixDiskMod: not base disk, not closing base VdlDisk" if $log
    end
  end

  # Disk size in sectors.
  def d_size
    @diskObj.info[:capacity]
  end
end
