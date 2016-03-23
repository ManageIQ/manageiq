# encoding: US-ASCII

require 'enumerator'
require 'disk/MiqDisk'
require 'active_support/core_ext/object/try'

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
    return nil unless lh

    pvh = readPvHeader(d, lh)

    mdList = []
    pvh.metadataDiskLocations.each do |dlh|
      mdah = readMdah(d, dlh)
      mdah.rawLocations.each do |rl|
        mdList << readRaw(d, rl)
      end
    end
    pvh.mdList = mdList
    pvh.lvm_type = lh.lvm_type.split(" ").first
    pvh
  end # def self.labelScan

  private

  def self.readLabel(d, s)
    d.seek(s * SECTOR_SIZE, IO::SEEK_SET)
    lh = readStruct(d, LABEL_HEADER)
    return lh if lh.lvm_id == LVM_ID
    nil
  end # def self.readLabel

  def self.readPvHeader(d, lh)
    pvho = (lh.sector_xl * SECTOR_SIZE) + lh.offset_xl
    d.seek(pvho)
    pvh = readStruct(d, PV_HEADER)

    #
    # Read and save disk location structures for data areas.
    #
    pvh.dataDiskLocations = []
    loop do
      dlh = readStruct(d, DISK_LOCN)
      break if dlh.offset == 0
      pvh.dataDiskLocations << dlh
    end

    #
    # Read and save disk location structures for metadata headers.
    #
    pvh.metadataDiskLocations = []
    loop do
      dlh = readStruct(d, DISK_LOCN)
      break if dlh.offset == 0
      pvh.metadataDiskLocations << dlh
    end

    pvh
  end # def self.readPvHeader

  def self.readMdah(d, dlh)
    d.seek(dlh.offset, IO::SEEK_SET)
    mdah = readStruct(d, MDA_HEADER)
    raise "** readMdah: unknown magic number" if mdah.magic != FMTT_MAGIC

    #
    # Read and save raw loaction headers for metadata.
    #
    mdah.rawLocations = []
    loop do
      rlh = readStruct(d, RAW_LOCN)
      break if rlh.offset == 0
      rlh.base = mdah.start
      mdah.rawLocations << rlh
    end

    mdah
  end # def self.readMdah

  def self.readRaw(d, rlh)
    osp = d.seekPos
    d.seek(rlh.base + rlh.offset, IO::SEEK_SET)
    da = d.read(rlh.size)
    d.seek(osp, IO::SEEK_SET)
    da
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

  def parse
    vgHash = {}
    parseObj(vgHash, @vgName)
    vg = vgHash[@vgName]

    getVgObj(@vgName, vg)
  end # def parse

  def self.dumpMetadata(md)
    level = 0
    md.lines do |line|
      line.strip!
      level -= 1 if line[0, 1] == HASH_END || line[0, 1] == ARRAY_END
      $log.info((level > 0 ? "    " * level : "") + line)
      level += 1 if line[-1, 1] == HASH_START || line[-1, 1] == ARRAY_START
    end
  end

  private

  def getVgObj(_vgName, vg)
    vgObj = VolumeGroup.new(vg['id'], @vgName, vg['extent_size'], vg['seqno'])
    vgObj.lvmType = "LVM2"
    vg["status"].each { |s| vgObj.status << s }

    vg["physical_volumes"].each { |pvName, pv| vgObj.physicalVolumes[pvName] = getPvObj(vgObj, pvName, pv) } unless vg["physical_volumes"].nil?
    vg["logical_volumes"].each { |lvName, lv| vgObj.logicalVolumes[lvName] = getLvObj(vgObj, lvName, lv) } unless vg["logical_volumes"].nil?

    vgObj
  end # def getVgObj

  def getPvObj(vgObj, pvName, pv)
    pvObj = PhysicalVolume.new(pv['id'].delete('-'), pvName, pv['device'], pv['dev_size'], pv['pe_start'], pv['pe_count'])
    # Add reference to volume group object to each physical volume object.
    pvObj.vgObj = vgObj

    dobj = @pvHdrs[pvObj.pvId].try(:diskObj)
    if dobj
      pvObj.diskObj = dobj
      dobj.pvObj = pvObj
    end

    pv["status"].each { |s| pvObj.status << s }

    pvObj
  end # def getPvObj

  def getLvObj(vgObj, lvName, lv)
    lvObj = LogicalVolume.new(lv['id'], lvName, lv['segment_count'])
    lvObj.vgObj = vgObj
    lv["status"].each { |s| lvObj.status << s }

    (1..lvObj.segmentCount).each { |seg| lvObj.segments << getSegObj(lv["segment#{seg}"]) }

    lvObj
  end # def getLvObj

  def getSegObj(seg)
    device_id = seg['device_id'].try(:to_i)
    segObj = LvSegment.new(seg['start_extent'], seg['extent_count'], seg['type'], seg['stripe_count'], device_id)
    segObj.thin_pool = seg['thin_pool'] if seg.key?('thin_pool')
    segObj.metadata  = seg['metadata']  if seg.key?('metadata')
    segObj.pool      = seg['pool']      if seg.key?('pool')
    seg['stripes'].each_slice(2) do |pv, o|
      segObj.stripes << pv
      segObj.stripes << o.to_i
    end unless seg['stripes'].nil?

    segObj
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
    h = {}
    name = @mda.shift
    while name && name != HASH_END
      parseObj(h, name)
      name = @mda.shift
    end
    h
  end

  def parseArray
    a = []
    val = @mda.shift
    while val && val != ARRAY_END
      a << parseVal(val)
      val = @mda.shift
    end
    a
  end

  def parseString
    s = ''
    word = @mda.shift
    while word && word != STRING_END
      s << word + " "
      word = @mda.shift
    end
    s.chomp(" ")
  end
end # class Lvm2MdParser

module Lvm2Thin
  SECTOR_SIZE = 512

  THIN_MAGIC = 27022010

  SPACE_MAP_ROOT_SIZE = 128

  MAX_METADATA_BITMAPS = 255

  SUPERBLOCK = BinaryStruct.new([
   'L',                       'csum',
   'L',                       'flags_',
   'Q',                       'block',
   'A16',                     'uuid',
   'Q',                       'magic',
   'L',                       'version',
   'L',                       'time',

   'Q',                       'trans_id',
   'Q',                       'metadata_snap',

   "A#{SPACE_MAP_ROOT_SIZE}", 'data_space_map_root',
   "A#{SPACE_MAP_ROOT_SIZE}", 'metadata_space_map_root',

   'Q',                       'data_mapping_root',

   'Q',                       'device_details_root',

   'L',                       'data_block_size',     # in 512-byte sectors

   'L',                       'metadata_block_size', # in 512-byte sectors
   'Q',                       'metadata_nr_blocks',

   'L',                       'compat_flags',
   'L',                       'compat_ro_flags',
   'L',                       'incompat_flags'
  ])

  SPACE_MAP = BinaryStruct.new([
    'Q',                      'nr_blocks',
    'Q',                      'nr_allocated',
    'Q',                      'bitmap_root',
    'Q',                      'ref_count_root'
  ])

  DISK_NODE = BinaryStruct.new([
    'L',                      'csum',
    'L',                      'flags',
    'Q',                      'blocknr',

    'L',                      'nr_entries',
    'L',                      'max_entries',
    'L',                      'value_size',
    'L',                      'padding'
    #'Q',                      'keys'
  ])

  INDEX_ENTRY = BinaryStruct.new([
    'Q',                      'blocknr',
    'L',                      'nr_free',
    'L',                      'none_free_before'
  ])

  METADATA_INDEX = BinaryStruct.new([
    'L',                      'csum',
    'L',                      'padding',
    'Q',                      'blocknr'
  ])

  BITMAP_HEADER = BinaryStruct.new([
    'L',                      'csum',
    'L',                      'notused',
    'Q',                      'blocknr'
  ])

  DEVICE_DETAILS = BinaryStruct.new([
    'Q',                      'mapped_blocks',
    'Q',                      'transaction_id',
    'L',                      'creation_time',
    'L',                      'snapshotted_time'
  ])

  MAPPING_DETAILS = BinaryStruct.new([
    'Q',                       'value'
  ])

  class BTree
    FLAGS = { :internal => 1, :leaf => 2}

    attr_accessor :root_address

    def initialize(superblock, root_address, value_type)
      @superblock   = superblock
      @root_address = root_address
      @value_type   = value_type
    end

    def root
      @root ||= begin
        @superblock.seek root_address
        @superblock.read_struct DISK_NODE
      end
    end

    def internal?
      (root['flags'] & FLAGS[:internal]) != 0
    end

    def leaf?
      (root['flags'] & FLAGS[:leaf]) != 0
    end

    def num_entries
      @num_entries ||= root['nr_entries']
    end

    def max_entries
      @max_entries ||= root['max_entries']
    end

    def key_base
      root_address + DISK_NODE.size
    end

    def key_address(i)
      key_base + i * 8
    end

    def value_base
      key_address(max_entries)
    end

    def value_address(i)
      value_base + @value_type.size * i
    end

    def keys
      @keys ||= begin
        @superblock.seek key_base
        @superblock.read(num_entries * 8).unpack("Q#{num_entries}")
      end
    end

    def entries
      @entries ||= begin
        @superblock.seek value_base
        @superblock.read_structs @value_type, num_entries
      end
    end

    def entry_for(key)
      entries[keys.index(key)]
    end

    def to_h
      @h ||=
        Hash[0.upto(num_entries-1).collect do |i|
          k = keys[i]
          e = entries[i].kind_of?(BTree) ? entries[i].to_h : entries[i]
          [k, e]
        end]
    end

    def [](key)
      return to_h[key]
    end
  end

  class DataMap < BTree
    TIME_MASK = (1 << 24) - 1

    def initialize(superblock, root_address)
      super superblock, root_address, MAPPING_DETAILS
    end

    alias :device_blocks :keys

    def entries
      @dmentries ||= begin
        super.collect do |entry|
          value = entry['value']
          internal? ? DataMap.new(@superblock, @superblock.md_block_address(value)) :
                      [extract_data_block(value), extract_time(value)]
        end
      end
    end

    def data_block(device_block)
      device_blocks.reverse.each do |map_device_block|
        if map_device_block <= device_block
          entry = entry_for(map_device_block)
          return entry.data_block(device_block) if entry.is_a?(DataMap)
          raise RuntimeError, "LVM2Thin cannot find device block: #{device_block} (closest: #{map_device_block})" unless map_device_block == device_block
          return entry.first
        end
      end

      raise RuntimeError, "LVM2Thin could not find data block for #{device_block}"
    end

    private

    def extract_data_block(value)
      value >> 24
    end

    def extract_time(value)
      value & TIME_MASK
    end
  end

  class MappingTree < BTree
    def initialize(superblock, root_address)
      super superblock, root_address, MAPPING_DETAILS
    end

    def entries
      @mtentries ||= begin
        super.collect do |entry|
          DataMap.new @superblock, @superblock.md_block_address(entry['value'])
        end
      end
    end

    def map_for(device_id)
      entry_for(device_id)
    end
  end

  class DataSpaceMap
    attr_accessor :struct

    def initialize(superblock, struct)
      @superblock = superblock
      @struct = struct
    end

    def btree_root_address
      @btree_root_address ||= @superblock.md_block_address(struct['bitmap_root'])
    end

    def btree
      @btree ||= BTree.new @superblock, btree_root_address, INDEX_ENTRY
    end
  end

  class MetadataSpaceMap
    def metadata_root_address
      @metadata_root_address ||= @superblock.md_block_address(struct['bitmap_root'])
    end

    def root
      @metadata_root ||= begin
        @superblock.seek metadata_root_address
        @superblock.read_struct METADATA_INDEX
      end
    end

    def indices
      @metadata_indices ||= (struct['nr_blocks'].to_f / @superblock.entries_per_block).ceil
    end

    def index_entries
      @index_entries ||=
        0.upto(indices-1).collect do |i|
          address = metadata_root_address + METADATA_INDEX.size + i * INDEX_ENTRY.size
          @superblock.seek address
          @superblock.read_struct INDEX_ENTRY
        end
    end

    def bitmaps
      @bitmaps ||= index_entries.collect do |index_entry|
        @superblock.seek @superblock.md_block_address(index_entry['blocknr'])
        @superblock.read_struct BITMAP_HEADER
      end
    end

    attr_accessor :struct

    def initialize(superblock, struct)
      @superblock = superblock
      @struct     = struct
    end
  end

  class SuperBlock
    attr_accessor :metadata_volume

    attr_accessor :struct

    def self.get(metadata_volume)
      @superblock ||= begin
        superblock = SuperBlock.new
        superblock.metadata_volume = metadata_volume
        superblock.seek 0
        superblock.struct = superblock.read_struct SUPERBLOCK
        raise "unknown lvm2 thin metadata magic number" if superblock.struct.magic != THIN_MAGIC
        superblock
      end
    end

    ### superblock properties:

    def md_block_size
      @md_block_size ||= struct['metadata_block_size'] * 512 # = 4096
    end

    def md_block_address(blk_addr)
      blk_addr * md_block_size
    end

    def entries_per_block
      @entries_per_block ||= (md_block_size - BITMAP_HEADER.size) * 4
    end

    def data_block_size
      @data_block_size ||= struct['data_block_size'] * 512
    end

    def data_block_address(blk_addr)
      blk_addr * data_block_size
    end

    ### lvm thin structures:

    def data_space_map
      @data_space_map ||= begin
        seek SUPERBLOCK.offset('data_space_map_root')
        DataSpaceMap.new self, read_struct(SPACE_MAP)
      end
    end

    def metadata_space_map
      @metadata_space_map ||= begin
        seek SUPERBLOCK.offset('metadata_space_map_root')
        MetadataSpaceMap.new self, read_struct(SPACE_MAP)
      end
    end

    def data_mapping_address
      @data_mapping_address ||= md_block_address(struct['data_mapping_root'])
    end

    def data_mapping
      @data_mapping ||= MappingTree.new self, data_mapping_address
    end

    def device_details_address
      @device_details_address ||= md_block_address(struct['device_details_root'])
    end

    def device_details
      @device_details ||= BTree.new self, device_details_address, DEVICE_DETAILS
    end

    ### address resolution / mapping:

    def device_block(device_address)
      (device_address / data_block_size).to_i
    end

    def device_block_offset(device_address)
      device_address % data_block_size
    end

    # return array of tuples containing data volume addresses and lengths to
    # read from them to read the specified device offset & length
    def device_to_data(device_id, pos, len)
      dev_blk = device_block(pos)
      dev_off = device_block_offset(pos)

      total_len = 0
      data_blks = []

      num_data_blks = (len / data_block_size).to_i + 1
      0.upto(num_data_blks - 1) do |i|
        data_blk = data_mapping.map_for(device_id).data_block(dev_blk + i)

        blk_start = data_blk * data_block_size
        blk_len   = 0

        if i == 0
          blk_start += dev_off
          blk_len    = data_block_size - dev_off - 1

        elsif i == num_data_blks - 1
          blk_len = len - total_len

        else
          blk_len    = data_block_size
        end

        total_len += blk_len
        data_blks << [blk_start, blk_len]
      end

      data_blks
    end

    ### metadata volume disk helpers:

    def seek(pos)
      @metadata_volume.disk.seek pos
    end

    def read(n)
      @metadata_volume.disk.read n
    end

    def read_struct(struct)
      OpenStruct.new(struct.decode(@metadata_volume.disk.read(struct.size)))
    end

    def read_structs(struct, num)
      Array.new(num) do
        read_struct struct
      end
    end
  end # class SuperBlock
end # module Lvm2Thin

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

#
# One object of this class for each physical volume in a volume group.
#
class PhysicalVolume
  attr_accessor :pvId, :pvName, :device, :deviceSize, :peStart, :peCount, :status, :vgObj, :diskObj

  def initialize(pvId = nil, pvName = nil, device = nil, deviceSize = nil, peStart = nil, peCount = nil)
    @pvId = pvId                        # the UUID of this physical volume
    @pvName = pvName                    # the name of this physical volume
    @device = device                    # the physical volume's device node under /dev.
    @deviceSize = deviceSize            # the size if this physical volume (in )
    @peStart = peStart.to_i             # the sector number of the first physical extent on this PV
    @peCount = peCount.to_i             # the number of physical extents on this PV

    @status = []
    @vgObj = nil                        # a reference to this PV's volume group
    @diskObj = nil                      # a reference to the MiqDisk object for this PV
  end
end # class PhysicalVolume

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
