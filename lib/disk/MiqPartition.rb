require 'MiqDisk'

class MiqPartition < MiqDisk
    def initialize(baseDisk, pType, lbaStart, lbaEnd, partNum)
        @baseDisk = baseDisk
        $log.debug "MiqPartition<#{self.object_id}> initialize partition for: #{@baseDisk.dInfo.fileName}" if $log
        super(nil, baseDisk.dInfo.clone, pType, lbaStart, lbaEnd, partNum)
    end

    def d_init
        $log.debug "MiqPartition<#{self.object_id}> d_init called"
        @blockSize = @baseDisk.blockSize
    end

    def d_read(pos, len)
        @baseDisk.d_read(pos, len)
    end

    def d_write(pos, buf, len)
        @baseDisk.d_write(pos, buf, len)
    end

    def d_size
        raise "MiqPartition: d_size should not be called for partition"
    end

    def d_close
    end

end
