require 'MSCommon'

module MSVSDynamicDisk
	
  def d_init
    self.diskType = "MSVS Dynamic"
		self.blockSize = MSCommon::SECTOR_LENGTH
		if self.dInfo.mountMode == nil || self.dInfo.mountMode == "r"
			self.dInfo.mountMode = "r"
			fileMode = "r"
		elsif self.dInfo.mountMode == "rw"
			fileMode = "r+"
		else
			raise "Unrecognized mountMode: #{self.dInfo.mountMode}"
		end
		@msDisk_file = MiqLargeFile.open(@dInfo.fileName, fileMode)
		MSCommon.d_init_common(@dInfo, @msDisk_file)
  end
  	
	def getBase
	    return self
	end
    
	def d_read(pos, len)
		MSCommon.d_read_common(pos, len)
	end
  
	def d_write(pos, buf, len)
		MSCommon.d_write_common(pos, buf, len)
	end
	
  def d_close
    @msDisk_file.close
  end
    
  def d_size
   MSCommon.d_size_common
  end
end #module
