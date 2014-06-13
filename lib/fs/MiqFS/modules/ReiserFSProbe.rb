module ReiserFSProbe
	
	REISERFS_DISK_OFFSET_NEW = 64 * 1024
	REISERFS_DISK_OFFSET_OLD =  8 * 1024
	
	REISERFS_SUPER_SIZE		= 204
	
	REISERFS_MAGIC_OFFSET	= 52
	REISERFS_MAGIC_SIZE		= 10
	
	REISERFS_MAGIC1 = "ReIsErFs"
	REISERFS_MAGIC2 = "ReIsEr2Fs"
	REISERFS_MAGIC3 = "ReIsEr3Fs"
	
	def ReiserFSProbe.probe(dobj)
    return false unless dobj.kind_of?(MiqDisk)
    
		return true if ReiserFSProbe.isMagic?(ReiserFSProbe.getMagic(dobj,REISERFS_DISK_OFFSET_NEW))
		return true if ReiserFSProbe.isMagic?(ReiserFSProbe.getMagic(dobj,REISERFS_DISK_OFFSET_OLD))
		
		# No ReiserFS.
		return false
	end

  def ReiserFSProbe.getMagic(dobj, offset)
    # Assume ReiserFS - read superblock at desired offset.
		dobj.seek(offset) #new disk start offset.
		sb = dobj.read(REISERFS_SUPER_SIZE)
		
		return nil if sb.nil? 
		return nil if sb.size < (REISERFS_MAGIC_OFFSET + REISERFS_MAGIC_SIZE - 1)
		
		# Check magic at offset 52 for accepted ReiserFS identifiers.
		magic = sb[REISERFS_MAGIC_OFFSET, REISERFS_MAGIC_SIZE].strip
	end	
	
	def ReiserFSProbe.isMagic?(magic)
		return true if magic == REISERFS_MAGIC1
		return true if magic == REISERFS_MAGIC2
		return true if magic == REISERFS_MAGIC3
		return false
  end
end
