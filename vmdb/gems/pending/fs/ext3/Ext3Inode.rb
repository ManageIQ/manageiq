require 'Ext3DirectoryEntry'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext3
		
	# ////////////////////////////////////////////////////////////////////////////
	# // Data definitions.

	INODE = BinaryStruct.new([
		'S',	'file_mode',		# File mode (type and permission), see PF_ DF_ & FM_ below.
		'S',	'uid_lo',				# Lower 16-bits of user id.
		'L',	'size_lo',			# Lower 32-bits of size in bytes.
		'L',	'atime',				# Last access time.
		'L',	'ctime',				# Last change time.
		'L',	'mtime',				# Last modification time.
		'L',	'dtime',				# Time deleted.
		'S',	'gid_lo',				# Lower 16-bits of group id.
		'S',	'link_count',		# Link count.
		'L',	'sector_count',	# Sector count.
		'L',	'flags',				# Inode flags, see IF_ below.
		'L',	'unused1',			# Unused.
		'a48',	'blk_ptrs',		# 12 direct block pointers.
		'L',	'ind_ptr',			# 1 single indirect block pointer.
		'L',	'dbl_ind_ptr',	# 1 double indirect block pointer.
		'L',	'tpl_ind_ptr',	# 1 triple indirect block pointer.
		'L',	'gen_num',			# Generation number (NFS).
		'L',	'ext_attrib',		# Extended attribute block (ACL).
		'L',	'size_hi',			# Upper 32-bits of size in bytes or directory ACL.
		'L',	'frag_blk',			# Block address of fragment.
		'C',	'frag_idx',			# Fragment index in block.
		'C',	'frag_siz',			# Fragment size.
		'S',	'unused2',			# Unused.
		'S',	'uid_hi',				# Upper 16-bits of user id.
		'S',	'gid_hi',				# Upper 16-bits of group id.
		'L',	'unused3',			# Unused.
	])
  
  # Offset of block pointers for those files whose content is
  # a symbolic link of less than 60 chars.
  SYM_LNK_OFFSET  = 40
  SYM_LNK_SIZE    = 60
  
	# ////////////////////////////////////////////////////////////////////////////
	# // Class.

	class Inode
		
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
		
		# Inode flags.
		IF_SECURE_DEL	= 0x00000001	# wipe when deleting
		IF_KEEP_COPY	= 0x00000002	# never delete
		IF_COMPRESS		= 0x00000004	# compress content
		IF_SYNCHRO		= 0x00000008	# don't cache
		IF_IMMUTABLE	= 0x00000010	# file cannot change
		IF_APPEND			= 0x00000020	# always append
		IF_NO_DUMP		= 0x00000040	# don't cat
		IF_NO_ATIME		= 0x00000080	# don't update atime
		IF_HASH_INDEX	= 0x00001000	# if dir, has hash index
		IF_JOURNAL		= 0x00002000	# if using journal, is journal inode
		
		# Lookup table for File Mode to File Type.
		@@FM2FT = {
			Inode::FM_FIFO			=> DirectoryEntry::FT_FIFO,
			Inode::FM_CHAR			=> DirectoryEntry::FT_CHAR,
			Inode::FM_DIRECTORY	=> DirectoryEntry::FT_DIRECTORY,
			Inode::FM_BLOCK_DEV	=> DirectoryEntry::FT_BLOCK,
			Inode::FM_FILE			=> DirectoryEntry::FT_FILE,
			Inode::FM_SYM_LNK		=> DirectoryEntry::FT_SYM_LNK,
			Inode::FM_SOCKET		=> DirectoryEntry::FT_SOCKET
		}
		
		attr_reader :mode, :flags, :blockPointers, :length, :symlnk
		attr_reader :sngIndBlockPointer, :dblIndBlockPointer, :tplIndBlockPointer
		
		def initialize(buf)
			raise "Ext3::Inode.initialize: Nil buffer" if buf.nil?
			@in = INODE.decode(buf)
			
			@mode    = @in['file_mode']
			@flags   = @in['flags']
			@length  = @in['size_lo']
			@length += (@in['size_hi'] << 32) if not self.isDir?
			
			# NOTE: Unpack the direct block pointers separately.
			@blockPointers      = @in['blk_ptrs'].unpack('L12')
			@sngIndBlockPointer = @in['ind_ptr']
			@dblIndBlockPointer = @in['dbl_ind_ptr']
			@tplIndBlockPointer = @in['tpl_ind_ptr']
      
      # If this is a symlnk < 60 bytes, grab the link metadata.
			if self.isSymLink? and self.length < SYM_LNK_SIZE
				@symlnk = buf[SYM_LNK_OFFSET, SYM_LNK_SIZE]
				# rPath is a wildcard. Sometimes they allocate when length < SYM_LNK_SIZE.
				# Analyze each byte of the first block pointer & see if it makes sense as ASCII.
				@symlnk[0, 4].each_byte do |c|
					if not (c > 45 and c < 48) and not ((c > 64 and c < 91) or (c > 96 and c < 123))
						# This seems to be a block pointer, so nix @symlnk & pretend it's a regular file.
						@symlnk = nil
						break
					end
				end
			end
		end
		
		# ////////////////////////////////////////////////////////////////////////////
		# // Class helpers & accessors.
		
		def uid
			return (@in['uid_hi'] << 16) | @in['uid_lo']
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
    
		def aTime
			return Time.at(@in['atime'])
		end
		
		def cTime
			return Time.at(@in['ctime'])
		end
		
		def mTime
			return Time.at(@in['mtime'])
		end
		
		def dTime
			return Time.at(@in['dtime'])
		end
		
		def gid
			return (@in['gid_hi'] << 16) | @in['gid_lo']
		end
		
		def permissions
			return @in['file_mode'] & (MSK_PERM_OWNER | MSK_PERM_GROUP | MSK_PERM_USER)
		end
		
		def ownerPermissions
			return @in['file_mode'] & MSK_PERM_OWNER
		end
		
		def groupPermissions
			return @in['file_mode'] & MSK_PERM_GROUP
		end
		
		def userPermissions
			return @in['file_mode'] & MSK_PERM_USER
		end
		
		# ////////////////////////////////////////////////////////////////////////////
		# // Utility functions.
		
		def fileModeToFileType
			return @@FM2FT[@mode & MSK_FILE_MODE]
		end
		
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out += "File mode    : 0x#{'%04x' % @in['file_mode']}\n"
			out += "UID          : #{self.uid}\n"
			out += "Size         : #{self.length}\n"
			out += "ATime        : #{self.aTime}\n"
			out += "CTime        : #{self.cTime}\n"
			out += "MTime        : #{self.mTime}\n"
			out += "DTime        : #{self.dTime}\n"
			out += "GID          : #{self.gid}\n"
			out += "Link count   : #{@in['link_count']}\n"
			out += "Sector count : #{@in['sector_count']}\n"
			out += "Flags        : 0x#{'%08x' % @in['flags']}\n"
			out += "Direct block pointers:\n"
			12.times {|i| p = @blockPointers[i]; out += "  #{i} = 0x#{'%08x' % p}\n"}
			out += "Sng Indirect : 0x#{'%08x' % @in['ind_ptr']}\n"
			out += "Dbl Indirect : 0x#{'%08x' % @in['dbl_ind_ptr']}\n"
			out += "Tpl Indirect : 0x#{'%08x' % @in['tpl_ind_ptr']}\n"
			out += "Generation   : 0x#{'%08x' % @in['gen_num']}\n"
			out += "Ext attrib   : 0x#{'%08x' % @in['ext_attrib']}\n"
			out += "Frag blk adrs: 0x#{'%08x' % @in['frag_blk']}\n"
			out += "Frag index   : 0x#{'%02x' % @in['frag_idx']}\n"
			out += "Frag size    : 0x#{'%02x' % @in['frag_siz']}\n"
			return out
		end
		
	end
end
