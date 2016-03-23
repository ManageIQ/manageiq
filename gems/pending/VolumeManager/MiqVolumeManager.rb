require 'ostruct'
require 'sys-uname'
require 'binary_struct'
require 'VolumeManager/MiqLvm'
require 'VolumeManager/MiqLdm'
require 'VolumeManager/VolMgrPlatformSupport'
require 'disk/modules/RawDisk'

class MiqVolumeManager
  attr_accessor :rootTrees
  attr_reader :logicalVolumes, :physicalVolumes, :visibleVolumes, :hiddenVolumes, :allPhysicalVolumes, :vgHash, :lvHash, :diskFileNames

  def self.fromNativePvs
    return nil unless Sys::Platform::IMPL == :linux

    msg_pfx = "MiqVolumeManager.fromNativePvs"

    bdevs = `pvdisplay -c | cut -d: -f1`.tr(" \t", "").split("\n")
    ldevs = `lvdisplay -c | cut -d: -f1`.tr(" \t", "").split("\n")
    bdevs -= ldevs
    bda = []

    bdevs.each do |bd|
      next if bd == "unknowndevice"
      $log.debug "#{msg_pfx}: Opening PV = #{bd}"

      diskInfo = OpenStruct.new
      diskInfo.rawDisk = true
      diskInfo.fileName = bd

      begin
        disk = MiqDisk.new(RawDisk, diskInfo, 0)
      rescue StandardError, NoMemoryError, SignalException => err
        $log.warn "#{msg_pfx}: Could not open PV: #{bd}"
        $log.warn err.to_s
        $log.debug err.backtrace.join("\n")
        next
      end

      raise "#{msg_pfx}: Failed to open disk: #{diskInfo.fileName}" unless disk
      bda << disk

      if $log.debug?
        $log.debug "#{msg_pfx}: Block device: #{bd}"
        $log.debug "#{msg_pfx}: \tDisk type: #{disk.diskType}"
        $log.debug "#{msg_pfx}: \tDisk partition type: #{disk.partType}"
        $log.debug "#{msg_pfx}: \tDisk block size: #{disk.blockSize}"
        $log.debug "#{msg_pfx}: \tDisk start LBA: #{disk.lbaStart}"
        $log.debug "#{msg_pfx}: \tDisk end LBA: #{disk.lbaEnd}"
        $log.debug "#{msg_pfx}: \tDisk start byte: #{disk.startByteAddr}"
        $log.debug "#{msg_pfx}: \tDisk end byte: #{disk.endByteAddr}"
      end
    end

    new(bda)
  end

  def initialize(pVols)
    @logicalVolumes     = []         # visible logical volumes
    @physicalVolumes    = []         # visible physical volumes
    @hiddenVolumes      = []         # hidded volumes (in volume groups)
    @allPhysicalVolumes = []         # all physical volumes
    @vgHash             = nil               # volume groups hashed by name
    @rootTrees          = nil               # the MiqMountManager objects using this MiqVolumeManager object
    @vdlConnection      = nil               # connection for remote vmdk access.

    lvmPvHdrHash = {}                 # physical volume header list, for lvm
    pVols.each do |pv|
      pvh = LdmScanner.scan(pv) || Lvm2Scanner.labelScan(pv)
      if pvh
        pvh.diskObj = pv                # add reference to the pv's open disk object to the pv header
        lvmPvHdrHash[pvh.pv_uuid] = pvh # this physical volume in an LVM volume group
        @hiddenVolumes << pv            # so it's a hidden volume
        $log.info "MiqVolumeManager: #{pvh.lvm_type} metadata detected on PV: #{pv.dInfo.fileName}, partition: #{pv.partNum}"
      else
        @physicalVolumes << pv          # this physical volume is not in an LVM volume group
        $log.debug "MiqVolumeManager: No LVM metadata detected on PV: #{pv.dInfo.fileName}, partition: #{pv.partNum}"
      end
      @allPhysicalVolumes << pv
    end

    @vgHash = {}
    parseLvmMetadata(lvmPvHdrHash)
    parseLvmThinMetadata
    @vgHash.each_value { |vg| @logicalVolumes.concat(vg.getLvs) }

    @lvHash = {}
    @logicalVolumes.each do |lvdObj|
      lv    = lvdObj.dInfo.lvObj
      lvName  = lv.lvName
      vgName  = lv.vgObj.vgName

      @lvHash["/dev/#{vgName}/#{lvName}"] = lvdObj
    end

    @visibleVolumes = @logicalVolumes + @physicalVolumes
  end

  def close
    $log.info "MiqVolumeManager.close called"
    @logicalVolumes     = @logicalVolumes.clear
    @physicalVolumes    = @physicalVolumes.clear
    @hiddenVolumes      = @hiddenVolumes.clear
    @vgHash             = nil
  end

  #
  # Physical volumes are opened by the client, so the client should be responsible
  # for closing them. These methods are provided as a convienience when the volume
  # manager is instantiated through fromNativePvs().
  #
  def closePvols
    @allPhysicalVolumes.each(&:close)
    @allPhysicalVolumes.clear
  end

  def closeAll
    $log.info "MiqVolumeManager.closeAll called"
    closePvols
    close
  end

  def parseLvmMetadata(pvHdrs)
    pvHdrs.each_value do |pvh|
      if pvh.lvm_type == "LVM2"
        $log.debug "MiqVolumeManager.parseLvmMetadata: parsing LVM2 metadata"
        pvh.mdList.each do |md|
          Lvm2MdParser.dumpMetadata(md) if $log.debug?
          parser = Lvm2MdParser.new(md, pvHdrs)
          next if @vgHash[parser.vgName]
          @vgHash[parser.vgName] = parser.parse
          # @vgHash[parser.vgName].dump
        end
      elsif pvh.lvm_type == "LDM"
        $log.debug "MiqVolumeManager.parseLvmMetadata: parsing LDM metadata"
        parser = LdmMdParser.new(pvh, pvHdrs)
        next if @vgHash[parser.vgName]
        @vgHash[parser.vgName] = parser.parse
      else
        $log.debug "MiqVolumeManager.parseLvmMetadata: unknown metadata type #{pvh.lvm_type}"
        next
      end
    end
  end

  def parseLvmThinMetadata
    @vgHash.each do |vgname, vg|
      $log.debug "MiqVolumeManager.parseLvmThinMetadata: setting LVM2 thin metadata"

      vg.thin_volumes.each do |tv|
        tv.thin_segments.each do |seg|
          seg.set_thin_pool_volume vg.logicalVolumes.values
        end
      end

      vg.thin_pool_volumes.each do |tpv|
        tpv.thin_pool_segments.each do |seg|
          seg.set_metadata_volume vg.logicalVolumes.values
          seg.set_data_volume     vg.logicalVolumes.values
        end
      end
    end
  end

  def toXml(doc = nil)
    doc = MiqXml.createDoc(nil) unless doc

    vi = doc.add_element 'volumes'
    pvToXml(vi, false)
    pvToXml(vi, true)
    lvToXml(vi)
    vgToXml(vi)
    doc
  end

  def pvToXml(doc = nil, hidden = false)
    doc = MiqXml.createDoc(nil) unless doc

    if hidden
      vols = @hiddenVolumes
      volType = 'hidden'
    else
      vols = @physicalVolumes
      volType = 'physical'
    end

    pvs = doc.add_element volType
    vols.each do |dobj|
      pv = pvs.add_element('volume',               "controller"        => dobj.hwId,
                                                   "disk_type"         => dobj.diskType,
                                                   "location"          => dobj.partNum,
                                                   "partition_type"    => dobj.partType,
                                                   "size"              => dobj.size,
                                                   "virtual_disk_file" => dobj.dInfo.fileName,
                                                   "start_address"     => dobj.startByteAddr,)
      if @rootTrees && @rootTrees.length > 0
        pv.add_attribute("name", @rootTrees[0].osNames[dobj.hwId].to_s) if @rootTrees[0].osNames

        fs = @rootTrees[0].fileSystems.find { |f| f.fs.dobj.hwId == dobj.hwId }
        unless fs.nil?
          pv.add_attributes("filesystem" => fs.fs.fsType,
                            "free_space" => fs.fs.freeBytes,
                            "used_space" => dobj.size - fs.fs.freeBytes)
        end
      end

      if dobj.pvObj
        pv.add_attributes("volume_group" => dobj.pvObj.vgObj.vgName,
                          "uid"          => dobj.pvObj.pvId)
      end
    end
    doc
  end

  def lvToXml(doc = nil)
    doc = MiqXml.createDoc(nil) unless doc

    lvs = doc.add_element 'logical'
    @logicalVolumes.each do |dobj|
      lvObj = dobj.dInfo.lvObj
      name = lvObj.driveHint.blank? ? lvObj.lvName : lvObj.driveHint
      lv = lvs.add_element('volume',               "name"         => name,
                                                   "type"         => dobj.diskType,
                                                   "size"         => dobj.size,
                                                   "uid"          => lvObj.lvId,
                                                   "volume_group" => lvObj.vgObj.vgName,
                                                   "drive_hint"   => lvObj.driveHint,
                                                   "volume_name"  => lvObj.lvName,)

      if @rootTrees && @rootTrees.length > 0
        fs = @rootTrees[0].fileSystems.find { |f| f.fs.dobj.dInfo.lvObj && f.fs.dobj.dInfo.lvObj.lvName == lvObj.lvName }
        unless fs.nil?
          lv.add_attributes("filesystem" => fs.fs.fsType,
                            "free_space" => fs.fs.freeBytes,
                            "used_space" => dobj.size - fs.fs.freeBytes)
        end
      end
    end
    doc
  end

  def vgToXml(doc = nil)
    doc = MiqXml.createDoc(nil) unless doc

    vgs = doc.add_element 'volume_groups'
    @vgHash.each do |vgn, vgo|
      pext = 0
      lext = 0

      vg = vgs.add_element('volume_group', {"name" => vgn})

      pvs = vg.add_element 'physical'
      vgo.physicalVolumes.each do |pvn, pvo|
        pv = pvs.add_element('volume',                   "name"              => pvn,
                                                         "uid"               => pvo.pvId,
                                                         "controller"        => pvo.diskObj.hwId,
                                                         "os_name"           => pvo.device,
                                                         "physical_extents"  => pvo.peCount,
                                                         "virtual_disk_file" => pvo.diskObj.dInfo.fileName)
        pext += pvo.peCount
      end

      lvs = vg.add_element 'logical'
      vgo.logicalVolumes.each do |lvn, lvo|
        lv = lvs.add_element('volume',                   "name" => lvn,
                                                         "uid"  => lvo.lvId)
        lvo.segments.each { |s| lext += s.extentCount }
      end

      vg.add_attributes("extent_size"      => vgo.extentSize,
                        "physical_extents" => pext,
                        "logical_extents"  => lext,
                        "free_extents"     => pext - lext)
    end if @vgHash
    doc
  end
end # class MiqVolumeManager
