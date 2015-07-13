module UnionFSProbe
	
	UNIONFS_SUPER_OFFSET	= 1024
	UNIONFS_MAGIC_OFFSET	= 52
	UNIONFS_MAGIC_SIZE		= 4
	UNIONFS_MAGIC					= 0xf15f083d
	
	def UnionFSProbe.probe(dobj)
    return false unless dobj.kind_of?(MiqDisk)
		
		# Assume UnionFS - read magic at offset.
		dobj.seek(UNIONFS_SUPER_OFFSET + UNIONFS_MAGIC_OFFSET)
		magic = dobj.read(UNIONFS_MAGIC_SIZE).unpack('L')
		raise "UnionFS is Not Supported" if magic == UNIONFS_MAGIC
		
		# No UnionFS.
		return false
	end
end
