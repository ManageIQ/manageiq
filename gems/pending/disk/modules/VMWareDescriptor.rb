require 'pathname'

module VMWareDescriptor
  def d_init
    # Check to see if a descriptor was not embedded.
    descriptor = dInfo.Descriptor
    if descriptor.nil?
      f = File.open(dInfo.fileName, "rb")
      descriptor = f.read; f.close
    end

    # Make sure this is a descriptor.
    desc, defs = parseDescriptor(descriptor, dInfo.fileName)
    raise "No disk definitions" if defs.size == 0
    # Make sure each disk is there.
    defs.each do|diskDef|
      raise "No disk file: #{diskDef['filename']}" unless File.exist?(diskDef['filename'])
    end

    # Init needed stff.
    self.diskType = "VMWare Descriptor"
    self.blockSize = 512
    @desc     = desc  # This disk descriptor.
    @defs     = defs  # Disk extent definitions.
    @ostructs = []    # Component OpenStructs for disk objects.
    @disks    = []    # Component MiqDisk objects (one for each disk).

    # If there's a parent parse it first (all subordinate disks need a ref to parent).
    if desc.key?('parentFileNameHint')
      @parentOstruct = OpenStruct.new

      # Get the parentFileNameHint and be sure it is relative to the descriptor file's directory
      parentFileName = Pathname.new(desc['parentFileNameHint'])
      if parentFileName.absolute?
        parentFileName = parentFileName.relative_path_from(Pathname.new(dInfo.fileName).dirname)
        $log.debug "VMWareDescriptor: Parent disk file is absolute. Using relative path [#{parentFileName}]" if $log
      end
      parentFileName = File.dirname(dInfo.fileName) + "/" + parentFileName.to_s.tr("\\", "/")
      $log.debug "VMWareDescriptor: Getting parent disk file [#{parentFileName}]" if $log

      @parentOstruct.fileName = parentFileName
      @parentOstruct.mountMode = dInfo.mountMode
      @parentOstruct.hardwareId = dInfo.hardwareId if dInfo.baseOnly
      d = MiqDisk.getDisk(@parentOstruct)
      raise "MiqDisk#getDisk returned nil for parent disk #{@parentOstruct.fileName}" if d.nil?
      @parent = d
      return if dInfo.baseOnly
    end

    # Instance MiqDisks for each disk definition.
    defs.each do |diskDef|
      thisO = OpenStruct.new
      thisO.Descriptor = dInfo.Descriptor if dInfo.Descriptor
      thisO.parent = @parent
      thisO.fileName = diskDef['filename']
      thisO.offset = diskDef['offset']
      thisO.rawDisk = true if diskDef['type'].strip == 'FLAT'
      thisO.rawDisk = true if diskDef['type'].strip == 'VMFS'
      thisO.mountMode = dInfo.mountMode
      @ostructs << thisO
      d = MiqDisk.getDisk(thisO)
      raise "MiqDisk#getDisk returned nil for component disk #{thisO.fileName}" if d.nil?
      @disks << d
    end
  end

  def getBase
    @parent || self
  end

  def d_read(pos, len)
    # $log.debug "VMWareDescriptor.d_read << pos #{pos} len #{len}" if $log && $log.debug?
    # Get start and end extents.
    dStart = getTargetDiskIndex((pos / @blockSize).ceil)
    dEnd   = getTargetDiskIndex(((pos + len) / @blockSize).ceil)

    if dStart == dEnd
      # Case: single extent.
      retBytes = @disks[dStart].d_read(pos, len, getDiskByteOffset(dStart))
    else
      # Case: span extents.
      retBytes = ""; bytesRead = 0
      dStart.upto(dEnd) do |diskIdx|
        readLen = @disks[diskIdx].d_size

        # Adjust length for start and end extents.
        readLen -= pos if diskIdx == dStart
        readLen -= (len - bytesRead) if diskIdx == dEnd

        # Read.
        retBytes << @disks[diskIdx].d_read(pos + bytesRead, readLen, getDiskByteOffset(diskIdx))
        bytesRead += readLen
      end
    end
    # $log.debug "VMWareDescriptor.d_read >> retBytes.length #{retBytes.length}" if $log && $log.debug?
    retBytes
  end

  def d_write(pos, buf, len)
    dStart = getTargetDiskIndex((pos / @blockSize).ceil)
    dEnd   = getTargetDiskIndex(((pos + len) / @blockSize).ceil)

    # Case: single extent.
    return @disks[dStart].d_write(pos, buf, len, getDiskByteOffset(dStart)) if dStart == dEnd

    # Case: span extents.
    bytesWritten = 0
    dStart.upto(dEnd) do |diskIdx|
      writeLen = @disks[diskIdx].d_size

      # Adjust length for start and end extents.
      writeLen -= pos if diskIdx == dStart
      writeLen -= (len - bytesWritten) if diskIdx == dEnd

      # Write.
      bytesWritten += @disks[diskIdx].d_write(pos + bytesWritten, writeLen, getDiskByteOffset(diskIdx))
    end
    bytesWritten
  end

  # Close all disks.
  def d_close
    @parent.close unless @parent.nil?
    @disks.each(&:close)
  end

  # Return size in sectors.
  def d_size
    total = 0
    @defs.each { |diskDef| total += diskDef['size'].to_i }
    total
  end

  # Get target disk index based on sector number.
  def getTargetDiskIndex(sector)
    dIdx = -1; total = 0
    0.upto(@defs.size - 1) do|idx|
      total += @defs[idx]['size'].to_i
      if total >= sector
        dIdx = idx
        break
      end
    end
    raise "Sector is past end of disk: #{sector}" if dIdx == -1
    raise "Disk object is nil for #{sector}" if @disks[dIdx].nil?
    dIdx
  end

  # Get beginning byte offset of target disk.
  def getDiskByteOffset(target)
    total = 0
    0.upto(@defs.size - 1) do|idx|
      break if idx == target
      total += @defs[idx]['size'].to_i
    end
    total * @blockSize
  end

  # This is all from metadata/vmdk.rb
  def parseDescriptor(descriptor, fname)
    defs  = []
    dict  = {}

    descriptor.each_line do |line|
      line.chomp!; line.strip!
      next if line.length == 0 || line[0, 1] == "\#"
      eqSign = line.index("=")
      if eqSign.nil?
        defs << parseDiskDescription(line, File.dirname(fname))
      else
        dict[line[0, eqSign].strip] = unquote(line[eqSign + 1..line.length - 1].strip)
      end
    end
    return dict, defs
  end

  def splitSpecial(line)
    two = line.split('"')
    out = two[0].split(' ')
    out << two[1]
    out
  end

  def parseDiskDescription(line, dirname)
    elems = splitSpecial(line)
    nelems = elems.size
    raise "Not Enough Disk Parameters: #{line}" if nelems < 4
    raise "Too Many Disk Parameters: #{line}"   if nelems > 5

    disk = Hash["access", elems[0], "size", elems[1], "type", elems[2], "filename", elems[3], "offset", elems[4]]
    disk["filename"] = File.join(dirname, fixBrokenExtension(unquote(disk["filename"])))
    disk["offset"]   = 0 if (nelems == 4)
    disk
  end

  def unquote(str)
    str.delete!("\"")
    str.strip! unless str.nil?
    str
  end

  # Descriptors that pass through FAT file systems may have 8.3 names.
  # File.exist?("c:/window~1.vmd") will match "c:/window~1.vmdk", but
  # CreateFile will fail, so fix the extension.
  def fixBrokenExtension(fn)
    if fn[-4, 4] == ".vmd" then fn += "k" end
    if fn =~ /\.vmd[^k]/
      fn.gsub!(/\.vmd/, ".vmdk")
    end
    fn
  end

  private :parseDescriptor, :parseDiskDescription, :splitSpecial, :unquote, :fixBrokenExtension
end # module VMWareDescriptor
