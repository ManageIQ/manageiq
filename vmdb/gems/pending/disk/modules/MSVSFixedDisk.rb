$:.push("#{File.dirname(__FILE__)}")
require 'MiqLargeFile'

module MSVSFixedDisk
  def d_init
    @diskType = "MSVSFixed"
    @blockSize = 512
    
    if self.dInfo.mountMode == nil || self.dInfo.mountMode == "r"
      self.dInfo.mountMode = "r"
      fileMode = "r"
    elsif self.dInfo.mountMode == "rw"
      fileMode = "r+"
    else
      raise "Unrecognized mountMode: #{self.dInfo.mountMode}"
    end
    
    @msFlatDisk_file = MiqLargeFile.open(self.dInfo.fileName, fileMode)
  end
    
  def d_read(pos, len)
    @msFlatDisk_file.seek(pos, IO::SEEK_SET)
    @msFlatDisk_file.read(len)
  end
  	
	def getBase
	    return self
	end
	
	def d_write(pos, buf, len)
		@msFlatDisk_file.seek(pos, IO::SEEK_SET)
		@msFlatDisk_file.write(buf, len)
	end
    
  def d_close
    @msFlatDisk_file.close
  end
    
  def d_size
    File.size(self.dInfo.fileName)
  end
end
