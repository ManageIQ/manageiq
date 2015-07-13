$:.push("#{File.dirname(__FILE__)}")

require 'MiqLargeFile'

module RawDisk
	def d_init
		self.diskType = "Raw"
		self.blockSize = 512

		if self.dInfo.mountMode == nil || self.dInfo.mountMode == "r"
			self.dInfo.mountMode = "r"
			fileMode = "r"
		elsif self.dInfo.mountMode == "rw"
			fileMode = "r+"
		else
			raise "Unrecognized mountMode: #{self.dInfo.mountMode}"
		end

		@dOffset = self.dInfo.offset
		@rawDisk_file = MiqLargeFile.open(self.dInfo.fileName, fileMode)
	end

	def getBase
		return self
	end

	def d_read(pos, len, offset = 0)
		pos += @dOffset if @dOffset
		@rawDisk_file.seek(pos-offset, IO::SEEK_SET)
		@rawDisk_file.read(len)
	end
    
    def d_write(pos, buf, len, offset = 0)
        pos += @dOffset if @dOffset
		@rawDisk_file.seek(pos-offset, IO::SEEK_SET)
        @rawDisk_file.write(buf, len)
    end
    
    def d_close
        @rawDisk_file.close
    end
    
		# Disk size in sectors.
    def d_size
        @rawDisk_file.size / @blockSize
    end
end
