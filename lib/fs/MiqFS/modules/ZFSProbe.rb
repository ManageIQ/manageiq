module ZFSProbe
	
	ZFS_SUPER_OFFSET	= 0
	ZFS_MAGIC_OFFSET	= 0
	ZFS_MAGIC_SIZE		= 4
	ZFS_SUPER_MAGIC		= 0x00bab10c
	
	def ZFSProbe.probe(dobj)
    return(false) unless dobj.kind_of?(MiqDisk)
		
		# Check for magic at uberblock offset.
		dobj.seek(ZFS_SUPER_OFFSET + ZFS_MAGIC_OFFSET)
		magic = dobj.read(ZFS_MAGIC_SIZE).unpack('L')[0]
		raise "ZFS is Not Supported" if magic == ZFS_SUPER_MAGIC
		
		# No ZFS.
		return false
	end
end
