# encoding: US-ASCII

$:.push("#{File.dirname(__FILE__)}/../disk")

require 'enumerator'
require 'MiqDisk'

module Lvm2Scanner
    
    LVM_PARTITION_TYPE  = 142
    SECTOR_SIZE         = 512
    LABEL_SCAN_SECTORS  = 4
    
    LVM_ID_LEN          = 8
    LVM_TYPE_LEN        = 8
    LVM_ID              = "LABELONE"
    
    PV_ID_LEN           = 32
    MDA_MAGIC_LEN       = 16
    FMTT_MAGIC          = "\040\114\126\115\062\040\170\133\065\101\045\162\060\116\052\076"
    
    #
    # On disk label header.
    #
    LABEL_HEADER = BinaryStruct.new([
        "A#{LVM_ID_LEN}",       'lvm_id',
        'Q',                    'sector_xl',
        'L',                    'crc_xl',
        'L',                    'offset_xl',
        "A#{LVM_TYPE_LEN}",     'lvm_type'
    ])
    
    #
    # On disk physical volume header.
    #
    PV_HEADER = BinaryStruct.new([
        "A#{PV_ID_LEN}",        'pv_uuid',
        "Q",                    'device_size_xl'
    ])
    
    #
    # On disk disk location structure.
    #
    DISK_LOCN = BinaryStruct.new([
        "Q",                    'offset',
        "Q",                    'size'
    ])
    
    #
    # On disk metadata area header.
    #
    MDA_HEADER = BinaryStruct.new([
        "L",                    'checksum_xl',
        "A#{MDA_MAGIC_LEN}",    'magic',
        "L",                    'version',
        "Q",                    'start',
        "Q",                    'size'
    ])
    
    #
    # On disk raw location header, points to metadata.
    #
    RAW_LOCN = BinaryStruct.new([
        "Q",                    'offset',
        "Q",                    'size',
        "L",                    'checksum',
        "L",                    'filler'
    ])
    
    #
    # Scan the physical volume for LVM headers.
    # Return nil if no label is found.
    # Otherwise, return a physical volume header containing a list of metadata areas.
    #
    def self.labelScan(d)
        lh = nil
        (0...LABEL_SCAN_SECTORS).each do |s|
            lh = readLabel(d, s)
            break if lh
        end
        return nil if !lh
        
        pvh = readPvHeader(d, lh)
        
        mdList = Array.new
        pvh.metadataDiskLocations.each do |dlh|
            mdah = readMdah(d, dlh)
            mdah.rawLocations.each do |rl|
                mdList << readRaw(d, rl)
            end
        end
        pvh.mdList = mdList
		pvh.lvm_type = lh.lvm_type.split(" ").first
        return pvh
    end # def self.labelScan
    
    private
    
    def self.readLabel(d, s)
        d.seek(s * SECTOR_SIZE, IO::SEEK_SET)
        lh = readStruct(d, LABEL_HEADER)
        return lh if lh.lvm_id == LVM_ID
        return nil
    end # def self.readLabel
    
    def self.readPvHeader(d, lh)
        pvho = (lh.sector_xl * SECTOR_SIZE) + lh.offset_xl
        d.seek(pvho)
        pvh = readStruct(d, PV_HEADER)
        
        #
        # Read and save disk location structures for data areas.
        #
        pvh.dataDiskLocations = Array.new
        while true
            dlh = readStruct(d, DISK_LOCN)
            break if dlh.offset == 0
            pvh.dataDiskLocations << dlh
        end
        
        #
        # Read and save disk location structures for metadata headers.
        #
        pvh.metadataDiskLocations = Array.new
        while true
            dlh = readStruct(d, DISK_LOCN)
            break if dlh.offset == 0
            pvh.metadataDiskLocations << dlh
        end
        
        return pvh
    end # def self.readPvHeader
    
    def self.readMdah(d, dlh)
        d.seek(dlh.offset, IO::SEEK_SET)
        mdah = readStruct(d, MDA_HEADER)
        raise "** readMdah: unknown magic number" if mdah.magic != FMTT_MAGIC
        
        #
        # Read and save raw loaction headers for metadata.
        #
        mdah.rawLocations = Array.new
        while true
            rlh = readStruct(d, RAW_LOCN)
            break if rlh.offset == 0
            rlh.base = mdah.start
            mdah.rawLocations << rlh
        end
        
        return mdah
    end # def self.readMdah
    
    def self.readRaw(d, rlh)
        osp = d.seekPos
        d.seek(rlh.base + rlh.offset, IO::SEEK_SET)
        da = d.read(rlh.size)
        d.seek(osp, IO::SEEK_SET)
        return da
    end # def self.readRaw
    
    def self.readStruct(d, struct)
		OpenStruct.new(struct.decode(d.read(struct.size)))
    end # def self.readStruct

end # module Lvm2Scanner

class Lvm2MdParser
    
    HASH_START      = '{'
    HASH_END        = '}'
    ARRAY_START     = '['
    ARRAY_END       = ']'
    STRING_START    = '"'
    STRING_END      = '"'
    
    attr_reader :vgName
    
    def initialize(mdStr, pvHdrs)
        @pvHdrs = pvHdrs        # PV headers hashed by UUID
        @mda = mdStr.gsub(/#.*$/, "").gsub("[", "[ ").gsub("]", " ]").gsub('"', ' " ').delete("=,").gsub(/\s+/, " ").split(' ')
        @vgName = @mda.shift
    end # def initialize
    
    def parse()
        vgHash = Hash.new
        parseObj(vgHash, @vgName)
        vg = vgHash[@vgName]
        
        return getVgObj(@vgName, vg)
    end # def parse

	def self.dumpMetadata(md)
		level = 0
		md.lines do |line|
			line.strip!
			level -= 1 if line[0,1] == HASH_END || line[0,1] == ARRAY_END
			$log.info((level > 0 ? "    " * level : "") + line)
			level += 1 if line[-1,1] == HASH_START || line[-1,1] == ARRAY_START
		end
	end
    
    private
        
    def getVgObj(vgName, vg)
        vgObj = VolumeGroup.new(vg['id'], @vgName, vg['extent_size'], vg['seqno'])
		vgObj.lvmType = "LVM2"
        vg["status"].each { |s| vgObj.status << s }
        
        vg["physical_volumes"].each { |pvName, pv| vgObj.physicalVolumes[pvName] = getPvObj(vgObj, pvName, pv) } unless vg["physical_volumes"].nil?
        vg["logical_volumes"].each { |lvName, lv| vgObj.logicalVolumes[lvName] = getLvObj(vgObj, lvName, lv) } unless vg["logical_volumes"].nil?
        
        return vgObj
    end # def getVgObj

    def getPvObj(vgObj, pvName, pv)
        pvObj = PhysicalVolume.new(pv['id'].delete('-'), pvName, pv['device'], pv['dev_size'], pv['pe_start'], pv['pe_count'])
        # Add reference to volume group object to each physical volume object.
        pvObj.vgObj = vgObj
        # Add reference to the physical volume's open disk object to the physical volume object.
        dobj = @pvHdrs[pvObj.pvId].diskObj
        # Add reference to the physical volume object to the physical volume's open disk object.
        pvObj.diskObj = dobj
        pv["status"].each { |s| pvObj.status << s }
        dobj.pvObj = pvObj
        
        return pvObj
    end # def getPvObj

    def getLvObj(vgObj, lvName, lv)
        lvObj = LogicalVolume.new(lv['id'], lvName, lv['segment_count'])
        lvObj.vgObj = vgObj
        lv["status"].each { |s| lvObj.status << s }
                
        (1..lvObj.segmentCount).each { |seg| lvObj.segments << getSegObj(lv["segment#{seg}"]) }
        
        return lvObj
    end # def getLvObj
    
    def getSegObj(seg)
        segObj = LvSegment.new(seg['start_extent'], seg['extent_count'], seg['type'], seg['stripe_count'])
        seg['stripes'].each_slice(2) do |pv, o|
            segObj.stripes << pv
            segObj.stripes << o.to_i
        end
        
        return segObj
    end # def getSegObj
    
    def parseObj(parent, name)
        val = @mda.shift
        
        rv = case val
        when HASH_START
            parent[name] = parseHash
        when ARRAY_START
            parent[name] = parseArray
        else
            parent[name] = parseVal(val)
        end
    end
    
    def parseVal(val)
        if val == STRING_START
            return parseString
        else
            return val
        end
    end
    
    def parseHash
        h = Hash.new
        name = @mda.shift
        while name && name != HASH_END
            parseObj(h, name)
            name = @mda.shift
        end
        return h
    end
    
    def parseArray
        a = Array.new
        val = @mda.shift
        while val && val != ARRAY_END
            a << parseVal(val)
            val = @mda.shift
        end
        return a
    end
    
    def parseString
        s = String.new
        word = @mda.shift
        while word && word != STRING_END
            s << word + " "
            word = @mda.shift
        end
        return s.chomp(" ")
    end
    
end # class Lvm2MdParser

#
# One object of this class for each volume group.
#
class VolumeGroup
    attr_accessor :vgId, :vgName, :extentSize, :seqNo, :status, :physicalVolumes, :logicalVolumes, :lvmType
    
    def initialize(vgId=nil, vgName=nil, extentSize=nil, seqNo=nil)
        @vgId = vgId                        # the UUID of this volme group
        @vgName = vgName                    # the name of this volume group
        @extentSize = extentSize.to_i       # the size of all physical and logical extents (in sectors)
        @seqNo = seqNo
        
		@lvmType = nil
        @status = Array.new
        @physicalVolumes = Hash.new         # PhysicalVolume objects, hashed by name
        @logicalVolumes = Hash.new          # LogicalVolume objects, hashed by name
    end  

    def getLvs
        lvList = Array.new
        @logicalVolumes.each_value do |lvObj|
            #
            # get MiqDisk object for each LV and add to lvList.
            #
            dInfo = OpenStruct.new
            dInfo.lvObj = lvObj
            dInfo.hardwareId = ""
            begin
              lvList << MiqDisk.new(Lvm2DiskIO, dInfo, 0)
            rescue => err
              $log.warn "Failed to load MiqDisk for <#{dInfo.fileName}>.  Message:<#{err}>"
            end
        end
        return lvList
    end # def getLvs

    def dump
        $log.info "#{@vgName}:"
        $log.info "\tID: #{@vgId}"
        $log.info "\tseqno: #{@seqNo}"
        $log.info "\textent_size: #{@extentSize}"
        $log.info "\tstatus:"
        vg.status.each { |s| $log.info "\t\t#{s}" }

        $log.info "\n\tPhysical Volumes:"
        vg.physicalVolumes.each do |pvName, pv|
            $log.info "\t\t#{pvName}:"
            $log.info "\t\t\tID: #{pv.pvId}"
            $log.info "\t\t\tdevice: #{pv.device}"
            $log.info "\t\t\tdev_size: #{pv.deviceSize}"
            $log.info "\t\t\tpe_start: #{pv.peStart}"
            $log.info "\t\t\tpe_count: #{pv.peCount}"
            $log.info "\t\t\tstatus:"
            pv.status.each { |s| $log.info "\t\t\t\t#{s}" }
        end

        $log.info "\n\tLogical Volumes:"
        @logicalVolumes.each do |lvName, lv|
            $log.info "\t\t#{lvName}:"
            $log.info "\t\t\tID: #{lv.lvId}"
            $log.info "\t\t\tstatus:"
            lv.status.each { |s| $log.info "\t\t\t\t#{s}" }
            $log.info "\n\t\t\tSegments, count = #{lv.segmentCount}:"
            i = 0
            lv.segments.each do |s|
                $log.info "\t\t\t\tsegment - #{i}:"
                $log.info "\t\t\t\t\tstart_extent: #{s.startExtent}"
                $log.info "\t\t\t\t\textent_count: #{s.extentCount}"
                $log.info "\t\t\t\t\ttype: #{s.type}"
                $log.info "\t\t\t\t\tstripe_count: #{s.stripeCount}"
                $log.info "\n\t\t\t\t\tstripes:"
                s.stripes.each { |si| $log.info "\t\t\t\t\t\t#{si}" }
                i += 1
            end
        end
    end # def dump
end # class VolumeGroup

#
# One object of this class for each physical volume in a volume group.
#
class PhysicalVolume
    attr_accessor :pvId, :pvName, :device, :deviceSize, :peStart, :peCount, :status, :vgObj, :diskObj
    
    def initialize(pvId=nil, pvName=nil, device=nil, deviceSize=nil, peStart=nil, peCount=nil)
        @pvId = pvId                        # the UUID of this physical volume
        @pvName = pvName                    # the name of this physical volume
        @device = device                    # the physical volume's device node under /dev.
        @deviceSize = deviceSize            # the size if this physical volume (in )
        @peStart = peStart.to_i             # the sector number of the first physical extent on this PV
        @peCount = peCount.to_i             # the number of physical extents on this PV
        
        @status = Array.new
        @vgObj = nil                        # a reference to this PV's volume group
        @diskObj = nil                      # a reference to the MiqDisk object for this PV
    end
end # class PhysicalVolume

#
# One object of this class for each logical volume.
#
class LogicalVolume
    attr_accessor :lvId, :lvName, :segmentCount, :segments, :status, :vgObj, :lvPath, :driveHint
    
    def initialize(lvId=nil, lvName=nil, segmentCount=0)
        @lvId = lvId                        # the UUID of this logical volume
        @lvName = lvName                    # the logical volume's name
		@lvPath = nil						# native use only
        @segmentCount = segmentCount.to_i   # the number of segments in this LV
        
		@driveHint = nil					# Drive hint, for windows
        @segments = Array.new               # array of this LV's LvSegment objects
        @status = Array.new
        @vgObj = nil                        # a reference to this LV's volume group
    end
end # class LogicalVolume

#
# One object of this class for each segment in a logical volume.
#
class LvSegment
    attr_accessor :startExtent, :extentCount, :type, :stripeCount, :stripes
    
    def initialize(startExtent=0, extentCount=0, type=nil, stripeCount=0)
        @startExtent = startExtent.to_i     # the first logical extent of this segment
        @extentCount = extentCount.to_i     # the number of logical extents in this segment
        @type = type                        # the type of segment
        @stripeCount = stripeCount.to_i     # the number of stripes in this segment(1 = linear)
        
        @stripes = Array.new                # <pvName, startPhysicalExtent> pairs for each stripe.
    end
end # class LvSegment

#
# MiqDisk support module for LVM2 logical volumes.
#
module Lvm2DiskIO
    
    def d_init
        @lvObj = self.dInfo.lvObj
        raise "Logical volume object not present in disk info." if !@lvObj
        @vgObj = @lvObj.vgObj
        self.diskType = "#{@vgObj.lvmType} Logical Volume"
        self.blockSize = 512
        
        @extentSize = @vgObj.extentSize * self.blockSize    # extent size in bytes
        
        @lvSize = 0
        @segments = Array.new
        @lvObj.segments.each do |lvSeg|
            seg = Segment.new(lvSeg.startExtent * @extentSize, ((lvSeg.startExtent + lvSeg.extentCount) * @extentSize) - 1, lvSeg.type)
            @lvSize += (seg.segSize/self.blockSize)
        
            #
            # Each slice is defined by a physical volume name and the extent
            # number of where the stripe starts on that physical volume.
            #
            lvSeg.stripes.each_slice(2) do |pvn, ext|
                pvObj = @vgObj.physicalVolumes[pvn]
                raise "Physical volume object (name=<#{pvn}>) not found in volume group (id=<#{@vgObj.vgId}> name=<#{@vgObj.vgName}>) of logical volume (id=<#{@lvObj.lvId}> name=<#{@lvObj.lvName}>)" if pvObj.nil?
                #
                # Compute the byte address of the start of the stripe on the physical volume.
                #
                ba = (pvObj.peStart * self.blockSize) + (ext * @extentSize)
                seg.stripes << Stripe.new(pvObj.diskObj, ba)
            end
            @segments << seg
        end
    end # def d_init
    
    def d_read(pos, len)
        retStr = String.new
        return retStr if len == 0
        
        endPos = pos + len - 1
        startSeg, endSeg = getSegs(pos, endPos)
        
        (startSeg..endSeg).each do |si|
            seg = @segments[si]
            
            srs = seg.startByteAddr     # segment read start
            srl = seg.segSize           # segment read length
            
            if si == startSeg
                srs = pos
                srl = seg.segSize - (pos - seg.startByteAddr)
            end
            if si == endSeg
                srl = endPos - srs + 1
            end
            retStr << readSeg(seg, srs, srl)
        end
        
        return retStr
    end # def d_read
    
    def d_write(pos, buf, len)
        raise "Write operation not yet supported for logical volumes"
    end # def d_write
    
    def d_close
    end # def d_close
    
    def d_size
        return @lvSize
    end # def d_size
    
    def logicalVolume
        return @lvObj
    end
    
    def volumeGroup
        return @vgObj
    end
    
    private
    
    def getSegs(startPos, endPos)
        startSeg = nil
        endSeg = nil
        
        @segments.each_with_index do |seg, i|
            startSeg = i if seg.byteRange === startPos
            if seg.byteRange === endPos
                raise "Segment sequence error" if !startSeg
                endSeg = i
                break
            end
        end
        raise "Segment range error: LV = #{@lvObj.lvName}, startPos = #{startPos}, endPos = #{endPos}" if !startSeg || !endSeg
        
        return startSeg, endSeg
    end
    
    def readSeg(seg, sba, len)
        #
        # For now, we only support linear segments (stripeCount = 1)
        # TODO: support other segment types.
        #
        stripe = seg.stripes[0]
        pvReadPos = stripe.pvStartByteAddr + (sba - seg.startByteAddr)     # byte address on the physical volume
        
        stripe.pvDiskObj.seek(pvReadPos, IO::SEEK_SET)
        return stripe.pvDiskObj.read(len) 
    end
    
    #
    # Like LvSegment but optimized for logical volume IO
    #
    class Segment
        attr_accessor :type, :stripes, :segSize, :byteRange
        
        def initialize(startByte, endByte, type=nil)
            @byteRange = Range.new(startByte, endByte, false)
            @type = type
            @segSize = endByte - startByte + 1
            @stripes = Array.new
        end
        
        def startByteAddr
            return @byteRange.begin
        end
        
        def endByteAddr
            return @byteRange.end
        end
    end
    
    class Stripe
        attr_accessor :pvDiskObj, :pvStartByteAddr
        
        def initialize(pvDisk, pvStart)
            @pvDiskObj = pvDisk
            @pvStartByteAddr = pvStart
        end
    end
    
end # module Lvm2DiskIO

if __FILE__ == $0
    md = IO.read("lvmt2_metadata")
    parser = Lvm2MdParser.new(md, nil)
    puts "Parsing metadata for volume group: #{parser.vgName}"
    vg = parser.parse
    vg.dump
    
    vg.logicalVolumes.each_value do |lv|
        puts "***** LV: #{lv.lvName} start *****"
        parser.dumpVg(lv.vgObj)
        puts "***** LV: #{lv.lvName} end *****"
    end
end
