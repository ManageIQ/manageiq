module RhevmDiskProbe
  DESC_MOD = "RhevmDescriptor"
  QCOW_MOD = "QcowDisk"
  RAW_MOD  = 'RawDisk'

  def RhevmDiskProbe.probe(ostruct)
    return nil if !ostruct.fileName

    ext = File.extname(ostruct.fileName).downcase
    return nil unless ext.length.zero?

    format = ostruct.format.to_s.downcase
    return RAW_MOD  if format == 'raw'
    return QCOW_MOD if format == 'cow'

    descriptor_file = ostruct.fileName + '.meta'
    return nil unless File.exist?(descriptor_file)

    # If this ostruct already has a descriptor don't bother checking.
    # NOTE: If it does have a descriptor, we're coming from RhevmDescriptor.rb
    #       trying to open a disk - so don't regress infinitely.
    if ostruct.Descriptor.nil?
      # Get descriptor metadata
      f = File.open(descriptor_file, "r")
      descriptor = f.read; f.close
      if descriptor.include?('EOF')
        ostruct.Descriptor = descriptor
        desc = parseDescriptor(descriptor)
        return RAW_MOD if desc[:format].to_s.include?('RAW')
        return QCOW_MOD if desc[:format].to_s.include?('COW')
        return DESC_MOD
      end
    else
      desc = parseDescriptor(ostruct.Descriptor)
      return RAW_MOD  if desc[:format].to_s.include?('RAW')
      return QCOW_MOD if desc[:format].to_s.include?('COW')
    end
    return nil
  end

  def RhevmDiskProbe.parseDescriptor(descriptor)
    desc = {}
    descriptor.each_line do |line|
      line.strip!
      break if line == 'EOF'
      next unless line.include?('=')
      key, *value = line.split('=')
      desc[key.downcase.to_sym] = value = value.join('=')
    end
    return desc
  end

end # module RhevmDiskProbe
