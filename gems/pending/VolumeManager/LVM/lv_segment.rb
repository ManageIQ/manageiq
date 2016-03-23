#
# One object of this class for each segment in a logical volume.
#
class LvSegment
  attr_accessor :startExtent, :extentCount, :type, :stripeCount, :stripes

  attr_accessor :thin_pool, :device_id # set for thin segments

  attr_accessor :metadata, :pool # set for thin pool segments

  attr_accessor :thin_pool_volume, :metadata_volume, :data_volume

  def initialize(startExtent = 0, extentCount = 0, type = nil, stripeCount = 0, deviceId=nil)
    @startExtent = startExtent.to_i     # the first logical extent of this segment
    @extentCount = extentCount.to_i     # the number of logical extents in this segment
    @type = type                        # the type of segment
    @stripeCount = stripeCount.to_i     # the number of stripes in this segment(1 = linear)

    @stripes = []                # <pvName, startPhysicalExtent> pairs for each stripe.
    @device_id = deviceId
  end

  def thin?
    type == 'thin'
  end

  def thin_pool?
    type == 'thin-pool'
  end

  def set_metadata_volume(lvs)
    @metadata_volume = lvs.find { |lv| lv.lvName == metadata }
  end

  def set_data_volume(lvs)
    @data_volume = lvs.find { |lv| lv.lvName == pool }
  end

  def set_thin_pool_volume(lvs)
    @thin_pool_volume = lvs.find { |lv| lv.lvName == thin_pool }
  end
end # class LvSegment

