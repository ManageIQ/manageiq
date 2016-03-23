require 'disk/MiqDisk'

#
# One object of this class for each logical volume.
#
class LogicalVolume
  attr_accessor :lvId, :lvName, :segmentCount, :segments, :status, :vgObj, :lvPath, :driveHint

  def initialize(lvId = nil, lvName = nil, segmentCount = 0)
    @lvId = lvId                        # the UUID of this logical volume
    @lvName = lvName                    # the logical volume's name
    @lvPath = nil           # native use only
    @segmentCount = segmentCount.to_i   # the number of segments in this LV

    @driveHint = nil          # Drive hint, for windows
    @segments = []               # array of this LV's LvSegment objects
    @status = []
    @vgObj = nil                        # a reference to this LV's volume group

    @superblock = nil         # thin metadata superblock (if this is a thin metadata volume)
  end

  # will raise exception if LogicalVolume is not thin metadata volume
  def superblock
    @superblock ||= Lvm2Thin::SuperBlock.get self
  end

   # MiqDisk object for volume
  def disk
    @disk ||= begin
      dInfo = OpenStruct.new
      dInfo.lvObj = self
      dInfo.hardwareId = ""
      MiqDisk.new(Lvm2DiskIO, dInfo, 0)
    end
  end

  def thin_segments
    @thin_segments ||= segments.select { |segment| segment.thin? }
  end

  def thin_segment
    thin_segments.first
  end

  def thin?
    !thin_segments.empty?
  end

  def thin_pool_volume
    return nil unless thin?
    return thin_segment.thin_pool_volume
  end

  def thin_pool_segments
    @thin_pool_segments ||= segments.select { |segment| segment.thin_pool? }
  end

  def thin_pool_segment
    thin_pool_segments.first
  end

  def thin_pool?
    !thin_pool_segments.empty?
  end

  def metadata_volume
    thin_pool_segment.metadata_volume
  end

  def data_volume
    thin_pool_segment.data_volume
  end
end # class LogicalVolume

