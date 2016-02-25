require 'disk/modules/MSCommon'

module MSVSDynamicDisk
  def d_init
    self.diskType = "MSVS Dynamic"
    self.blockSize = MSCommon::SECTOR_LENGTH
    if dInfo.mountMode.nil? || dInfo.mountMode == "r"
      dInfo.mountMode = "r"
      fileMode = "r"
    elsif dInfo.mountMode == "rw"
      fileMode = "r+"
    else
      raise "Unrecognized mountMode: #{dInfo.mountMode}"
    end
    @ms_disk_file = if dInfo.hyperv_connection
                      MSCommon.connect_to_hyperv(dInfo)
                    else
                      MiqLargeFile.open(dInfo.fileName, fileMode)
                    end
    MSCommon.d_init_common(dInfo, @ms_disk_file)
  end

  def getBase
    self
  end

  def d_read(pos, len)
    MSCommon.d_read_common(pos, len)
  end

  def d_write(pos, buf, len)
    MSCommon.d_write_common(pos, buf, len)
  end

  def d_close
    @ms_disk_file.close
  end

  def d_size
    MSCommon.d_size_common
  end
end # module
