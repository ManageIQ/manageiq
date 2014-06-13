require 'ReiserFSUtils'

module ReiserFS
	
	class DirectoryEntry

    ITEM_STAT_V1 = BinaryStruct.new([
      'v',  'mode',
      'v',  'nlinks',
      'v',  'uid',
      'v',  'gid',
      'V',  'size',
      'V',  'atime',
      'V',  'mtime',
      'V',  'ctime',
      'V',  'nblocks',
      'V',  'first'
    ])
    SIZEOF_ITEM_STAT_V1 = ITEM_STAT_V1.size

    ITEM_STAT_V2 = BinaryStruct.new([
      'v',  'mode',
      'a2', 'reserved',
      'V',  'nlinks',
      'Q',  'size',
      'V',  'uid',
      'V',  'gid',
      'V',  'atime',
      'V',  'mtime',
      'V',  'ctime',
      'V',  'nblocks',
      'V',  'first'
    ])
    SIZEOF_ITEM_STAT_V2 = ITEM_STAT_V2.size
    
    # Bits 0 to 8 of file mode.
		PF_O_EXECUTE	= 0x0001	# owner execute
		PF_O_WRITE		= 0x0002	# owner write
		PF_O_READ			= 0x0004	# owner read
		PF_G_EXECUTE	= 0x0008	# group execute
		PF_G_WRITE		= 0x0010	# group write
		PF_G_READ			= 0x0020	# group read
		PF_U_EXECUTE	= 0x0040	# user execute
		PF_U_WRITE		= 0x0080	# user write
		PF_U_READ			= 0x0100	# user read
		
		# For accessor convenience.
		MSK_PERM_OWNER = (PF_O_EXECUTE | PF_O_WRITE | PF_O_READ)
		MSK_PERM_GROUP = (PF_G_EXECUTE | PF_G_WRITE | PF_G_READ)
		MSK_PERM_USER  = (PF_U_EXECUTE | PF_U_WRITE | PF_U_READ)
		
		# Bits 9 to 11 of file mode.
		DF_STICKY			= 0x0200
		DF_SET_GID		= 0x0400
		DF_SET_UID		= 0x0800
		
		# Bits 12 to 15 of file mode.
		FM_FIFO				= 0x1000	# fifo device (pipe)
		FM_CHAR				= 0x2000	# char device
		FM_DIRECTORY	= 0x4000	# directory
		FM_BLOCK_DEV	= 0x6000	# block device
		FM_FILE				= 0x8000	# regular file
		FM_SYM_LNK		= 0xa000	# symbolic link
		FM_SOCKET			= 0xc000	# socket device
		
		# For accessor convenience.
		MSK_FILE_MODE = 0xf000
		MSK_IS_DEV		= (FM_FIFO | FM_CHAR | FM_BLOCK_DEV | FM_SOCKET)

    attr_reader :key, :blockObj

    def initialize(blockObj, itemHeader, key)
      @itemHeader = itemHeader
      @blockObj   = blockObj
      @key        = key
      @data       = @blockObj.getItem(itemHeader)
      @version    = @blockObj.getItemVersion(itemHeader)

      statStruct = @version == 0 ? ITEM_STAT_V1 : ITEM_STAT_V2
      statSize   = @version == 0 ? SIZEOF_ITEM_STAT_V1 : SIZEOF_ITEM_STAT_V2
      raise "Stat Structure Length Inconsistency" if statSize != @data.length
      @stat = statStruct.decode(@data)
      @mode = @stat['mode']
    end

		def isDir?
			return @mode & FM_DIRECTORY == FM_DIRECTORY
		end
		
		def isFile?
			return @mode & FM_FILE == FM_FILE
		end
		
		def isDev?
			return @mode & MSK_IS_DEV > 0
		end
		
    def isSymLink?
      return @mode & FM_SYM_LNK == FM_SYM_LNK
    end

		def permissions
			return @mode & (MSK_PERM_OWNER | MSK_PERM_GROUP | MSK_PERM_USER)
		end
		
		def ownerPermissions
			return @mode & MSK_PERM_OWNER
		end
		
		def groupPermissions
			return @mode & MSK_PERM_GROUP
		end
		
		def userPermissions
			return @mode & MSK_PERM_USER
		end

		def uid
			return @stat['uid']
		end

		def gid
			return @stat['gid']
		end

		def aTime
			return Time.at(@stat['atime'])
		end
		
		def cTime
			return Time.at(@stat['ctime'])
		end
		
		def mTime
			return Time.at(@stat['mtime'])
		end
		
		def length
		  return @stat['size']
	  end
		
  end
  
end
