$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../../VixDiskLib")

require 'VixDiskLib'

module VixDiskMod
    def d_init
        self.diskType = "VixDisk"
        @vdi = self.dInfo.vixDiskInfo
        @connection = @vdi[:connection]
        
        if self.dInfo.mountMode == nil || self.dInfo.mountMode == "r"
          self.dInfo.mountMode = "r"
          fileMode = VixDiskLib::VIXDISKLIB_FLAG_OPEN_READ_ONLY
        elsif self.dInfo.mountMode == "rw"
          fileMode = 0
        else
          raise "Unrecognized mountMode: #{self.dInfo.mountMode}"
        end
        
        self.dInfo.fileName = @vdi[:fileName]
        if !(@diskObj = self.dInfo.vixDiskObj)
            @diskObj = @connection.getDisk(@vdi[:fileName], fileMode)
            self.dInfo.vixDiskObj = @diskObj
        end
        self.blockSize = @diskObj.sectorSize
    end
    
    def getBase
      return self
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
