$:.push("#{File.dirname(__FILE__)}/../../util")

require 'pathname2'

module RhevmDescriptor

  def d_init

    # Make sure this is a descriptor.
    desc, defs = parseDescriptor(self.dInfo.Descriptor)

    # Make sure each disk is there.
    defs.each {|diskDef|
      filename = buildFilename(diskDef[:filename])
      raise "No disk file: #{filename}" unless File.exist?(filename)
    }

    # Init needed stff.
    self.diskType = "Rhevm Descriptor"
    self.blockSize = 512
    @desc			= desc	#This disk descriptor.
    @defs			= defs	#Disk extent definitions.
    @ostructs = []		#Component OpenStructs for disk objects.
    @disks    = []		#Component MiqDisk objects (one for each disk).

    # If there's a parent parse it first (all subordinate disks need a ref to parent).
    if desc.has_key?(:puuid) && desc[:puuid] != '00000000-0000-0000-0000-000000000000'
      @parentOstruct = OpenStruct.new

      # Get the parentFileNameHint and be sure it is relative to the descriptor file's directory
      parentFileName = buildFilename(desc[:puuid])
      #puts "#{self.class.name}: Getting parent disk file [#{parentFileName}]"

      @parentOstruct.fileName = parentFileName
      @parentOstruct.mountMode = self.dInfo.mountMode
      @parentOstruct.hardwareId = self.dInfo.hardwareId if self.dInfo.baseOnly
      d = MiqDisk.getDisk(@parentOstruct)
      raise "MiqDisk#getDisk returned nil for parent disk #{@parentOstruct.fileName}" if d.nil?
      @parent = d
      return if self.dInfo.baseOnly
    end

    # Instance MiqDisks for each disk definition.
    defs.each do |diskDef|
      thisO = OpenStruct.new
      thisO.Descriptor = self.dInfo.Descriptor if self.dInfo.Descriptor
      thisO.parent = @parent
      thisO.fileName = buildFilename(diskDef[:filename])
      thisO.offset = diskDef[:offset]
      thisO.rawDisk = true if diskDef[:format].to_s.include?('RAW')
      thisO.mountMode = self.dInfo.mountMode
      @ostructs << thisO
      d = MiqDisk.getDisk(thisO)
      raise "MiqDisk#getDisk returned nil for component disk #{thisO.fileName}" if d.nil?
      @disks << d
    end
  end

  def getBase
    return @parent || self
  end

  def d_read(pos, len)
    #$log.debug "RhevmDescriptor.d_read << pos #{pos} len #{len}" if $log && $log.debug?
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
    #$log.debug "RhevmDescriptor.d_read >> retBytes.length #{retBytes.length}" if $log && $log.debug?
    return retBytes
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
    return bytesWritten
  end

  # Close all disks.
  def d_close
    @parent.close if @parent != nil
    @disks.each {|disk| disk.close}
  end

  # Return size in sectors.
  def d_size
    return @desc[:size].to_i
  end

  # Get target disk index based on sector number.
  def getTargetDiskIndex(sector)
    dIdx = -1; total = 0
    0.upto(@defs.size - 1) {|idx|
      total += @defs[idx][:size].to_i
      if total >= sector
        dIdx = idx
        break
      end
    }
    raise "Sector is past end of disk: #{sector}" if dIdx == -1
    raise "Disk object is nil for #{sector}" if @disks[dIdx].nil?
    return dIdx
  end

  # Get beginning byte offset of target disk.
  def getDiskByteOffset(target)
    total = 0
    0.upto(@defs.size - 1) {|idx|
      break if idx == target
      total += @defs[idx]['size'].to_i
    }
    return total * @blockSize
  end

  def parseDescriptor(descriptor)
    desc = {}
    descriptor.each_line do |line|
      line.strip!
      break if line == 'EOF'
      next unless line.include?('=')
      key, *value = line.split('=')
      desc[key.downcase.to_sym] = value = value.join('=')
    end
    desc[:offset] = 0
    desc[:filename] = File.basename(self.dInfo.fileName)
    return desc, [desc]
  end

  def buildFilename(parent_uuid)
    parentFileName = Pathname2.new(parent_uuid)
    if parentFileName.absolute?
      parentFileName = parentFileName.relative_path_from(Pathname2.new(self.dInfo.fileName).dirname)
      $log.debug "#{self.class.name}: Parent disk file is absolute. Using relative path [#{parentFileName}]" if $log
    end
    File.join(File.dirname(self.dInfo.fileName), parentFileName.to_s.tr("\\", "/"))
  end

end # module RhevmDescriptor
