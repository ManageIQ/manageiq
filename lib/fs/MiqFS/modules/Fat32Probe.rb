module Fat32Probe
	def Fat32Probe.probe(dobj)
    $log.debug("Fat32Probe >> dobj=#{dobj}") if $log
    unless dobj.kind_of?(MiqDisk)
			$log.debug "Fat32Probe << FALSE because Disk Object class is not MiqDisk, but is '#{dobj.class.to_s}'" if $log
      return false
		end
		
		# Assume FAT32 - read boot sector.
		dobj.seek(0)
		bs = dobj.read(512)
		
		# Check byte 66 for 0x29 (extended signature).
		if bs[66] != 0x29
		  $log.debug("Fat32Probe << FALSE because there is no extended signature") if $log
  		return false 
		end
    
		# Check file system label for 'FAT32   '
		# NOTE: This works for MS tools but maybe not for others.
		fslabel = bs[82, 8].unpack('a8')[0].strip
		fat32 = (fslabel == 'FAT32') ? true : false
		if $log
  	  $log.debug("Fat32Probe << TRUE") if fat32
  	  $log.debug("Fat32Probe << FALSE because FS label is NOT FAT32, but is '#{fslabel}'") if not fat32
	  end
	  
	  return fat32
	end
end
