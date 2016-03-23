#
# MiqDisk support module for LVM2 logical volumes.
#
module Lvm2DiskIO
  def d_init
    @lvObj = dInfo.lvObj
    raise "Logical volume object not present in disk info." unless @lvObj
    @vgObj = @lvObj.vgObj
    self.diskType = "#{@vgObj.lvmType} Logical Volume"
    self.blockSize = 512

    @extentSize = @vgObj.extentSize * blockSize    # extent size in bytes

    @lvSize = 0
    @segments = []
    @lvObj.segments.each do |lvSeg|
      seg = Segment.new(lvSeg.startExtent * @extentSize, ((lvSeg.startExtent + lvSeg.extentCount) * @extentSize) - 1, lvSeg.type)
      seg.lvSeg = lvSeg
      @lvSize += (seg.segSize / blockSize)

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
        ba = (pvObj.peStart * blockSize) + (ext * @extentSize)
        seg.stripes << Stripe.new(pvObj.diskObj, ba)
      end
      @segments << seg
    end
  end # def d_init

  def d_read(pos, len)
    retStr = ''
    return retStr if len == 0

    if logicalVolume.thin?
      device_id = logicalVolume.thin_segment.device_id
      thin_pool = logicalVolume.thin_pool_volume
      data_blks = thin_pool.metadata_volume.superblock.device_to_data(device_id, pos, len)
      data_blks.each do |offset, len|
        thin_pool.data_volume.disk.seek offset
        retStr << thin_pool.data_volume.disk.read(len)
      end

      return retStr
    end

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

    retStr
  end # def d_read

  def d_write(_pos, _buf, _len)
    raise "Write operation not yet supported for logical volumes"
  end # def d_write

  def d_close
  end # def d_close

  def d_size
    @lvSize
  end # def d_size

  def logicalVolume
    @lvObj
  end

  def volumeGroup
    @vgObj
  end

  private

  def getSegs(startPos, endPos, segments=@segments)
    startSeg = nil
    endSeg = nil

    segments.each_with_index do |seg, i|
      startSeg = i if seg.byteRange === startPos
      if seg.byteRange === endPos
        raise "Segment sequence error" unless startSeg
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
    stripe.pvDiskObj.read(len)
  end

  #
  # Like LvSegment but optimized for logical volume IO
  #
  class Segment
    attr_accessor :type, :stripes, :segSize, :byteRange
    attr_accessor :lvSeg

    def initialize(startByte, endByte, type = nil)
      @byteRange = Range.new(startByte, endByte, false)
      @type = type
      @segSize = endByte - startByte + 1
      @stripes = []
    end

    def startByteAddr
      @byteRange.begin
    end

    def endByteAddr
      @byteRange.end
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
