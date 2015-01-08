$:.push("#{File.dirname(__FILE__)}/modules")
$:.push("#{File.dirname(__FILE__)}/../util")

require 'binary_struct'
require 'DiskProbe'
require 'disk_log'

class MiqDisk
    include DiskLog

    attr_accessor :diskType, :dInfo, :blockSize, :pvObj, :fs
    attr_reader   :lbaStart, :lbaEnd, :startByteAddr, :endByteAddr,
                  :partType, :partNum, :size, :hwId, :logName
    
    def self.getDisk(dInfo, probes = nil)
        debug "MiqDisk::getDisk: baseOnly = #{dInfo.baseOnly}"

        if (dm = DiskProbe.getDiskMod(dInfo, probes))
            d = self.new(dm, dInfo.clone, 0)

            if dInfo.baseOnly
                debug "MiqDisk::getDisk: baseOnly = true, returning parent: " \
                      "#{d.getBase.dInfo.fileName}"
                debug "MiqDisk::getDisk: child (current) disk file: " \
                      "#{dInfo.fileName}"
                return d.getBase
            end

            debug "MiqDisk::getDisk: baseOnly = false, returning: " \
                  "#{dInfo.fileName}"
            return d
        end

        return nil
    end

    def self.pushFormatSupportForDisk(disk, probes = nil)
        if ((dm = DiskProbe.getDiskModForDisk(disk, probes)))
          debug "#{self.name}.pushFormatSupportForDisk: pushing " \
                "#{dm.name} onto #{disk.logName}"
          di = disk.dInfo.clone
          di.downstreamDisk = disk
          d = self.new(dm, di, 0)
          disk.dInfo.upstreamDisk = d
          return d
        end

        debug "#{self.name}.pushFormatSupportForDisk: " \
              "no module to push for #{disk.logName}"

        return disk
    end
    
    def initialize(dm, dInfo, pType, *lbaSE)
        extend(dm) unless dm.nil?
        @dModule  = dm
        @dInfo    = dInfo
        @partType = pType
        @partNum  = lbaSE.length == 3 ? lbaSE[2] : 0
        @partitions = nil
        @pvObj    = nil
        @fs     = nil   # the filesystem that resides on this disk

        if dInfo.lvObj
          @logName = "logical volume: #{dInfo.lvObj.vgObj.vgName}/#{dInfo.lvObj.lvName}"
        else
          @logName = "disk file: #{dInfo.fileName}"
        end
        @logName << " (partition: #{@partNum})"
        $log.debug "MiqDisk<#{self.object_id}> initialize, #{@logName}"

        d_init()
        
        case lbaSE.length
            when 0
                @lbaStart = 0
                @lbaEnd   = d_size
            when 1
                @lbaStart = lbaSE[0]
                @lbaEnd   = d_size
            else
                @lbaStart = lbaSE[0]
                @lbaEnd   = lbaSE[1] + @lbaStart # lbaSE[1] is the partiton size in sectors
        end
        
        @startByteAddr = @lbaStart * @blockSize
        @endByteAddr   = @lbaEnd * @blockSize
        @size          = @endByteAddr - @startByteAddr
        @seekPos       = @startByteAddr

        @dInfo.diskSig ||= getDiskSig if @partNum == 0 && !@dInfo.baseOnly
        @hwId = "#{@dInfo.hardwareId}:#{@partNum}" if @dInfo.hardwareId
    end

    def pushFormatSupport
        self.class.pushFormatSupportForDisk(self)
    end
    
    def diskSig
        @dInfo.diskSig ||= getDiskSig
    end
    
    def getPartitions
        discoverPartitions
    end
    
    def seekPos
        return @seekPos - @startByteAddr
    end
    
    def seek(amt, whence=IO::SEEK_SET)
        case whence
            when IO::SEEK_CUR
                @seekPos += amt
            when IO::SEEK_END
                @seekPos = @endByteAddr + amt
            when IO::SEEK_SET
                @seekPos = amt + @startByteAddr
            else
        end
        return @seekPos
    end
    
    def read(len)
        rb = d_read(@seekPos, len)
        @seekPos += rb.length unless rb.nil?
        return rb
    end
    
    def write(buf, len)
        nbytes = d_write(@seekPos, buf, len)
        @seekPos += nbytes
        return nbytes
    end
    
    def close
        debug "MiqDisk<#{self.object_id}> close, #{@logName}"
        @partitions.each { |p| p.close } if @partitions
        @partitions = nil
        d_close
    end
    
    private
    
    MBR_SIZE = 512
    DOS_SIG  = "55aa"
    DISK_SIG_OFFSET = 0x1B8
    DISK_SIG_SIZE = 4
    
    def getDiskSig
        sp = seekPos
        seek(DISK_SIG_OFFSET, IO::SEEK_SET)
        ds = read(DISK_SIG_SIZE).unpack('L')[0]
        seek(sp, IO::SEEK_SET)
        return ds
    end
    
    def discoverPartitions
        return @partitions unless @partitions.nil?

        debug "MiqDisk<#{self.object_id}> discoverPartitions, " \
              "disk file: #{@dInfo.fileName}"
        seek(0, IO::SEEK_SET)
        mbr = read(MBR_SIZE)
        
        if mbr.length < MBR_SIZE
            info "MiqDisk<#{self.object_id}> discoverPartitions, " \
                 "disk file: #{@dInfo.fileName} does not contain a master boot record"
            return @partitions = Array.new
        end
        
        sig = mbr[510..511].unpack('H4')
        
        return(discoverDosPriPartitions(mbr)) if sig[0] == DOS_SIG
        return @partitions = Array.new
    end
    
    DOS_PARTITION_ENTRY = BinaryStruct.new([
        'C', :bootable,
        'C', :startCHS0,
        'C', :startCHS1,
        'C', :startCHS2,
        'C', :ptype,
        'C', :endCHS0,
        'C', :endCHS1,
        'C', :endCHS1,
        'L', :startLBA,
        'L', :partSize
    ])

    PTE_LEN       = DOS_PARTITION_ENTRY.size
    DOS_PT_START  = 446
    DOS_NPTE      = 4
    PTYPE_EXT_CHS = 0x05
    PTYPE_EXT_LBA = 0x0f
    PTYPE_LDM     = 0x42
    
    def discoverDosPriPartitions(mbr)
        require 'MiqPartition'

        pte = DOS_PT_START
        @partitions = Array.new
        (1..DOS_NPTE).each do |n|
            ptEntry = DOS_PARTITION_ENTRY.decode(mbr[pte, PTE_LEN])
            pte += PTE_LEN
            ptype = ptEntry[:ptype]

            #
            # If this os an LDM (dynamic) disk, then ignore any partitions.
            #
            if ptype == PTYPE_LDM
              debug "MiqDisk::discoverDosPriPartitions: detected LDM (dynamic) disk"
              @partType = PTYPE_LDM
              return([])
      
            elsif ptype == PTYPE_EXT_CHS || ptype == PTYPE_EXT_LBA
                @partitions.concat(discoverDosExtPartitions(ptEntry[:startLBA], ptEntry[:startLBA], DOS_NPTE+1))
                next
            end
            @partitions.push(MiqPartition.new(self, ptype, ptEntry[:startLBA], ptEntry[:partSize], n)) if ptype != 0
        end
        return @partitions
    end
    
    # Discover secondary file system partitions within a primary extended partition.
    #
    # priBaseLBA is the LBA of the primary extended partition.
    #     All pointers to secondary extended partitions are relative to this base.
    #
    # ptBaseLBA is the LBA of the partition table within the current extended partition.
    #     All pointers to secondary file system partitions are relative to this base.
    def discoverDosExtPartitions(priBaseLBA, ptBaseLBA, pNum)
        ra = Array.new
        seek(ptBaseLBA * @blockSize, IO::SEEK_SET)
        mbr = read(MBR_SIZE)
        
        # Create and add disk object for secondary file system partition.
        # NOTE: the start of the partition is relative to ptBaseLBA.
        pte = DOS_PT_START
        ptEntry = DOS_PARTITION_ENTRY.decode(mbr[pte, PTE_LEN])
        ra << MiqPartition.new(self, ptEntry[:ptype], ptEntry[:startLBA] + ptBaseLBA, ptEntry[:partSize], pNum) if ptEntry[:ptype] != 0
        
        # Follow the chain to the next secondary extended partition.
        # NOTE: the start of the partition is relative to priBaseLBA.
        pte += PTE_LEN
        ptEntry = DOS_PARTITION_ENTRY.decode(mbr[pte, PTE_LEN])
        ra.concat(discoverDosExtPartitions(priBaseLBA, ptEntry[:startLBA] + priBaseLBA, pNum+1)) if ptEntry[:startLBA] != 0
        
        return ra
    end
end
