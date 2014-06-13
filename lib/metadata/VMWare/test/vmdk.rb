#!/usr/bin/env ruby
require 'binary_struct'

SPARSE_EXTENT_HEADER = BinaryStruct.new([
  'a4',       'magic',               # /* uint32	magicNumber - ASCII "KDMV" */
  'V',        'version',             # /* uint32	version                    */
  'V',        'flags',               # /* uint32	flags                      */
  'Q',        'capacity',            # /* uint64	capacity                   */
  'Q',        'grainSize',           # /* uint64  grainSize 		             */
  'Q',        'descriptorOffset',    # /* uint64	descriptorOffset   	       */
  'Q',        'descriptorSize',      # /* uint64	descriptorSize     	       */
  'V',        'numGTEsPerGT',        # /* uint32	numGTEsPerGT               */
  'Q',        'rgdOffset',           # /* uint64	rgdOffset   		           */
  'Q',        'gdOffset',            # /* uint64	gdOffset   		             */
  'Q',        'overhead',            # /* uint64	overHead   		             */
  'C',        'uncleanShutdown',     # /* uint8 	uncleanShutdown 	         */
  'a',        'singleEndLineChar',   # /* char 	  singleEndLineChar 	       */
  'a',        'nonEndLineChar',      # /* char 	  nonEndLineChar 	   	       */
  'a2',       'doubleEndLineChar1',  # /* char 	  doubleEndLineChar1 	       */
  'a2',       'doubleEndLineChar2',  # /* char 	  doubleEndLineChar2 	       */
	'x435',     nil,                   # /* uint8[435] pad                     */
])
SIZEOF_SPARSE_EXTENT_HEADER = SPARSE_EXTENT_HEADER.size

MBR_PARTITION_TABLE_ENTRY = BinaryStruct.new([
    'C',   'Flag',                   # /* 0x80 if Bootable */
    'a3',  'startCHS',               # /* Starting Sector in CHS Format -- Cylinder/Head/Sector */
    'C',   'Type',                   # /* Partition Type - 07=NTFS */
    'a3',  'lastCHS',                # /* Last Sector in CHS Format */
    'V',   'Offset',
    'V',   'Length',
])
SIZEOF_MBR_PARTITION_TABLE_ENTRY = MBR_PARTITION_TABLE_ENTRY.size


def parseDiskDescription(line, dirname)
  elems = line.split(' ')
  nelems = elems.size
  raise "Not Enough Disk Parameters: line" if (nelems < 4)
  raise "Too Many Disk Parameters: line"   if (nelems > 5)

  disk = Hash["access", elems[0], "size", elems[1], "type", elems[2], "filename", elems[3], "offset", elems[4] ]
  disk["filename"] = File.join(dirname,unquote(disk["filename"]))
  disk["offset"]   = 0 if (nelems == 4)

  return disk
end

def unquote(string)
  if ((string[0,1] == "\"") && (string[string.length-1,1] == "\""))
    string = string[1..string.length-2]
  end
  return string
end

def parseDescriptor(fname)
  ndisks = 0
  disks  = Hash.new()
  dict   = Hash.new()
  file   = File.open(fname)

  file.readlines.each { |line|
      line.chomp!; line.strip!
      next if line.length == 0 || line[0,1] == "\#"
      eqSign = line.index("=")
      if (eqSign == nil) then
        disks[ndisks] = parseDiskDescription(line, File.dirname(fname) )
        ndisks += 1
      else
        dict[line[0,eqSign].strip] = unquote(line[eqSign+1..line.length-1].strip)
      end
  }
  file.close

  return dict, disks
end

def bytesPerSector
  return 512
end

def extractFile(f,offset,size)
  f.seek(offset)
  return f.read(size)
end

def parseDiskGrainDirectory(f,h)
  offset = h["gdOffset"] * bytesPerSector()
  size   = h["directorySize"] * 4
  data   = extractFile(f,offset,size)
  return data.unpack('V*')
end

def parseDiskGrainTable(f,h,gt)
  offset = gt * bytesPerSector()
  size   = h["numGTEsPerGT"] * 4
  data   = extractFile(f,offset,size)
  grains = data.unpack('V*')
  grains.delete(0)
  return grains
end

def parseDiskGrain(f,h,g)
  offset = g * bytesPerSector()
  size   = h["grainSize"] * bytesPerSector()
  data   = extractFile(f,offset,size)
puts "parseDiskGrain -- offset=#{offset}"
puts "parseDiskGrain -- size=#{size}"
  return data
end

def num2partitiontype(num)
  case(num)
    when   7: return "NTFS"
    when  12: return "FAT32"
    when 131: return "ext2"
  end
  return num
end

def parsePTE(data)
  return nil if "0" * 16 == data

  pte = MBR_PARTITION_TABLE_ENTRY.decode(data)
#    if { $PTE(Flag) == -128 } { set PTE(Flag) Bootable }
  pte["Type"] = num2partitiontype(pte["Type"])

  p pte
end

def parseMBR(data)
  magic = data[510,2]
  raise "Bad Magic Number" if magic != "\x55\xAA"

  ntsig = data[440..443]

  if ntsig != "\x00\x00\x00\x00" then
    code = data[0..209]
    emsg = data[300..379]
    offsets = data[437..439]
  end

  ptab = data[446..509]
  ptetab  = []
  ptetab << ptab[0..15]
  ptetab << ptab[16..31]
  ptetab << ptab[32..47]
  ptetab << ptab[48..63]

  ptetab.each { |pte| parsePTE(pte) }

end


def parseDiskSparse(disk)
  File.open(disk["filename"], "rb") { |f|
    head_string = f.read(SIZEOF_SPARSE_EXTENT_HEADER)
    raise "No header!" unless head_string

    h = SPARSE_EXTENT_HEADER.decode(head_string)

    h["ngrains"]       = h["capacity"] / h["grainSize"]
    h["gtCoverage"]    = h["numGTEsPerGT"] * h["grainSize"]
    h["directorySize"] = (h["capacity"] + h["gtCoverage"] - 1) / h["gtCoverage"]

    p h

    grainTables = parseDiskGrainDirectory(f,h)

    mbr = nil

    grainTables.each { |gt|
      next unless mbr == nil
puts "GrainTable: #{gt}"
      grains = parseDiskGrainTable(f,h,gt)
      grains.each { |g|
        puts "Grain: #{g}"
        grain = parseDiskGrain(f,h,g)
        if mbr == nil then
          mbr = grain[0,512]
          parseMBR(mbr)
        end
      }
    }
  }
end

def parseDisk(disk)
  case disk["type"]
    when "SPARSE":  parseDiskSparse(disk)
    else            raise "Unrecognized Disk Type - #{disk["type"]}"
  end
end

def parse(fname)
  dict, disks = parseDescriptor(fname)
  p disks
  p dict
  disks.each_value { |v| parseDisk(v) }
end


fname = "/Users/oleg/Parallels/VMware Mount Test Directory/w2k3svrg.exported.vmdk"
parse(fname)
