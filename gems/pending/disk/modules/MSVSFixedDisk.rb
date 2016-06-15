require 'disk/modules/MiqLargeFile'

module MSVSFixedDisk
  def d_init
    @diskType = "MSVSFixed"
    @blockSize = 512

    if dInfo.hyperv_connection
      @ms_flat_disk_file = MSCommon.connect_to_hyperv(dInfo)
    else
      @ms_flat_disk_file = MiqLargeFile.open(dInfo.fileName, dInfo.fileMode)
    end
  end

  def d_read(pos, len)
    @ms_flat_disk_file.seek(pos, IO::SEEK_SET)
    @ms_flat_disk_file.read(len)
  end

  def getBase
    self
  end

  def d_write(pos, buf, len)
    @ms_flat_disk_file.seek(pos, IO::SEEK_SET)
    @ms_flat_disk_file.write(buf, len)
  end

  def d_close
    @ms_flat_disk_file.close
  end

  def d_size
    File.size(dInfo.fileName)
  end
end
