require 'time'

module VmxConfig  
	def convert(filename)
		#$log.debug "Processing VMware Configuration file [#{filename}]"
		fileData = File.read(filename)
		
		# Append the .vmsd file data.  Centralized file for storing information and metadata about snapshots.
		begin
      f=nil
			vmsd_filename = File.join(File.dirname(filename), File.basename(filename, ".*") + ".vmsd")
      f = File.open(vmsd_filename)
      fileData << convert_vmsd(f)
		rescue
    ensure
      f.close if f
		end
		return fileData
	end

  def convert_vmsd(f)
    # Only read the enabled snapshots from the file and ignore the rest
    numSnapshots = timeHigh = timeLow = nil
    knownSnapshots = []
    fileData = ""

    # First we need to find how many snapshots
    f.each_line do |line|
      # After that keep reading, but only store up to that many snapshots from the file
      if line =~ /numSnapshots = "(\d+)"/
        numSnapshots = $1.to_i
        break
      end
    end

    f.each_line do |line|
      if line =~ /^snapshot(\d+)/
        lastReadSnapshot = $1.to_i
        if !knownSnapshots.include?(lastReadSnapshot)
          next if knownSnapshots.length == numSnapshots
          knownSnapshots << lastReadSnapshot
        end

        # Check for createTimeHigh and createTimeLow and convert them
        #   The pack/unpack is needed so that the negative numbers get converted correctly
        skipLine = false

        if line =~ /createTimeHigh = \"(-?\d+)\"/
          timeHigh = [$1.to_i].pack('L').unpack('L')[0] << 32
          skipLine = true
        end

        if line =~ /createTimeLow = \"(-?\d+)\"/
          timeLow = [$1.to_i].pack('L').unpack('L')[0]
          skipLine = true
        end

        if timeHigh && timeLow
          begin
            create_time = Time.at(((timeHigh + timeLow) / 1000000.0)).getutc.iso8601(6)
            fileData << "snapshot#{lastReadSnapshot}.create_time = \"#{create_time}\"\n"
          rescue
          end
          timeHigh = timeLow = nil
        end

        next if skipLine
      end

      fileData << line
    end
    return fileData
  end

    def diskCreateType(filename)
      diskAttribute(filename, "createtype")
    end

    def diskControllerType(filename)
      diskAttribute(filename, "adaptertype")
    end
    
    def diskAttribute(filename, attr)
        f = File.join(@configPath, filename)
        retVal = getDiskAttribute(f, attr)
        
        # If we are uable to get the data from the disk, check if this is
        # a snapshot disk and try to look at the base disk.
        if retVal.nil? && isSnapshotDisk(f)
          bf = getBaseDiskName(f)
          retVal = getDiskAttribute(bf, attr)
        end
        
        return retVal
    end
    
    def getDiskAttribute(filename, attr)
        retVal = nil
        begin
            if File.exist?(filename)
                File.read(filename, 2048).each_line do |line|
                    if line.downcase.include?(attr)
                       retVal = line.split("=")[1].strip.tr("\"", "")
                       break
                    end
                end
            end
        rescue
        end
        return retVal
    end

    def isSnapshotDisk(filename)
      return getBaseDiskName(filename) != filename
    end

    def getBaseDiskName(filename)
      fn = File.basename(filename, File.extname(filename))
      if fn[-7,1] == "-" && !fn[-6..-1].to_i.zero?
        return File.join(File.dirname(filename), fn[0...-7] + File.extname(filename))
      else
        return filename
      end
    end
    
    def getVmType()
        type = @cfgHash.each_pair do |k,v|
            # Look for any disk with the create type of vmfs
            break(v) if k.downcase.include?("createtype") && v[0..3].downcase === "vmfs"
        end
        return "ESX" if type.is_a?(String) && type[0..3].downcase == "vmfs"
        return "Server"
    end
    
    def getScsiType()
      #scsiType = "lsilogic"
      scsiType = nil
      # Check scsi 0 to 3 for the Virtual Dev scsi value
      0.upto(3) do |i|
        if @cfgHash["scsi#{i}.virtualdev"]
          stype = @cfgHash["scsi#{i}.virtualdev"]
          scsiType = stype if ["lsilogic", "buslogic"].include?(stype.downcase)
          break
        end
      end
      
      # If we did not find the type on the adapter check the disks
      if scsiType.nil?
        type = @cfgHash.each_pair do |k,v|
            # Look for any disk with the adapterType set
            break(v) if k.downcase.include?("adaptertype") && ["lsilogic", "buslogic"].include?(v.downcase)
        end
        scsiType = type if type.is_a?(String)
      end
			return "lsilogic" if scsiType.nil?
      return scsiType
    end

  def vendor
    return "vmware"
  end
end
