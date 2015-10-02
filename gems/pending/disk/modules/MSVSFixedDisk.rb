require 'disk/modules/MiqLargeFile'

module MSVSFixedDisk
  def d_init
    @diskType = "MSVSFixed"
    @blockSize = 512

    if dInfo.mountMode.nil? || dInfo.mountMode == "r"
      dInfo.mountMode = "r"
      fileMode = "r"
    elsif dInfo.mountMode == "rw"
      fileMode = "r+"
    else
      raise "Unrecognized mountMode: #{dInfo.mountMode}"
    end

    @msFlatDisk_file = MiqLargeFile.open(dInfo.fileName, fileMode)
  end

  def d_read(pos, len)
    @msFlatDisk_file.seek(pos, IO::SEEK_SET)
    @msFlatDisk_file.read(len)
  end

  def getBase
    self
  end

  def d_write(pos, buf, len)
    @msFlatDisk_file.seek(pos, IO::SEEK_SET)
    @msFlatDisk_file.write(buf, len)
  end

  def d_close
    @msFlatDisk_file.close
  end

  def d_size
    File.size(dInfo.fileName)
  end
end
