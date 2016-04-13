#
# One object of this class for each volume group.
#
class VolumeGroup
  attr_accessor :vgId, :vgName, :extentSize, :seqNo, :status, :physicalVolumes, :logicalVolumes, :lvmType

  def initialize(vgId = nil, vgName = nil, extentSize = nil, seqNo = nil)
    @vgId = vgId                        # the UUID of this volme group
    @vgName = vgName                    # the name of this volume group
    @extentSize = extentSize.to_i       # the size of all physical and logical extents (in sectors)
    @seqNo = seqNo

    @lvmType = nil
    @status = []
    @physicalVolumes = {}         # PhysicalVolume objects, hashed by name
    @logicalVolumes = {}          # LogicalVolume objects, hashed by name
  end

  def thin_pool_volumes
    @thin_pool_volumes ||= logicalVolumes.values.select { |lv| lv.thin_pool? }
  end

  def thin_volumes
    @thin_volumes ||= logicalVolumes.values.select { |lv| lv.thin? }
  end

  def getLvs
    lvList  = []
    skipLvs = []
    @logicalVolumes.each_value do |lvObj|
      # remove logical volumes w/ 'thin-pool' segments as they are handled internally
      if lvObj.thin_pool?
        skipLvs << lvObj.lvName unless skipLvs.include?(lvObj.lvName)
        metadata_volume_names = lvObj.thin_pool_segments.collect { |tps| tps.metadata }
        data_volume_names     = lvObj.thin_pool_segments.collect { |tps| tps.pool     }
        (metadata_volume_names + data_volume_names).each do |vol|
          skipLvs <<  vol unless skipLvs.include?(vol)
        end
      end
    end

    @logicalVolumes.each_value do |lvObj|
      if skipLvs.include?(lvObj.lvName)
        $log.debug "Ignoring thin volume: #{lvObj.lvName}"
        next
      end

      begin
        lvList << lvObj.disk
      rescue => err
        $log.warn "Failed to load MiqDisk for <#{lvObj.disk.dInfo.fileName}>.  Message:<#{err}> #{err.backtrace}"
      end
    end
    lvList
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
