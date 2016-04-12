require 'active_support/core_ext/object/try'

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
      $log.debug((level > 0 ? "    " * level : "") + line)
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
