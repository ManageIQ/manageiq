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
