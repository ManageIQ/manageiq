module Iso9660Probe
	
	ISO9660FS_SUPER_OFFSET	= 32768
	ISO9660FS_MAGIC_OFFSET	= 1
	ISO9660FS_MAGIC_SIZE		= 5
	ISO9660FS_MAGIC					= "CD001"
	
	def Iso9660Probe.probe(dobj)
		return false unless dobj.kind_of?(MiqDisk)
		
		# Assume ISO9660 - read magic at offset.
		dobj.seek(ISO9660FS_SUPER_OFFSET + ISO9660FS_MAGIC_OFFSET)
		magic = dobj.read(ISO9660FS_MAGIC_SIZE)
		return true if magic == ISO9660FS_MAGIC
		
		# Not ISO9660.
		return false
	end	
end
