module NTFSProbe
	def NTFSProbe.probe(dobj)
	  $log.debug("NTFSProbe >> dobj=#{dobj}") if $log
		unless dobj.kind_of?(MiqDisk)
			$log.debug "NTFSProbe << FALSE because Disk Object class is not MiqDisk, but is '#{dobj.class.to_s}'" if $log
      return false
		end
		
		# Check for oem name = NTFS.
    dobj.seek(3)
    oem = dobj.read(8).unpack('a8')[0].strip
    
		ntfs = oem == 'NTFS'
		if $log
  	  $log.debug("NTFSProbe << TRUE") if ntfs
  	  $log.debug("NTFSProbe << FALSE because OEM Name is not NTFS, but is '#{oem}'") if not ntfs
	  end
	  
	  return ntfs
	end
end
