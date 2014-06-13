require 'Ext3GroupDescriptorTable'
require 'Ext3Inode'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'miq-uuid'
require 'stringio'
require 'MiqMemory'

require 'rufus/lru'

module Ext3
		
	# ////////////////////////////////////////////////////////////////////////////
	# // Data definitions. Linux 2.6.2 from Fedora Core 6.

	SUPERBLOCK = BinaryStruct.new([
		'L',	'num_inodes',					# Number of inodes in file system.
		'L',	'num_blocks',					# Number of blocks in file system.
		'L',	'reserved_blocks',		# Number of reserved blocks to prevent file system from filling up.
		'L',	'unallocated_blocks',	# Number of unallocated blocks.
		'L',	'unallocated_inodes',	# Number of unallocated inodes.
		'L',	'block_group_zero',		# Block where block group 0 starts.
		'L',	'block_size',					# Block size (saved as num bits to shift 1024 left).
		'L',	'fragment_size',			# Fragment size (saved as num bits to shift 1024 left).
		'L',	'blocks_in_group',		# Number of blocks in each block group.
		'L',	'fragments_in_group',	# Number of fragments in each block group.
		'L',	'inodes_in_group',		# Number of inodes in each block group.
		'L',	'last_mount_time',		# Time FS was last mounted.
		'L',	'last_write_time',		# Time FS was last written to.
		'S',	'mount_count',				# Current mount count.
		'S',	'max_mount_count',		# Maximum mount count.
		'S',	'signature',					# Always 0xef53
		'S',	'fs_state',						# File System State: see FSS_ below.
		'S',	'err_method',					# Error Handling Method: see EHM_ below.
		'S',	'ver_minor',					# Minor version number.
		'L',	'last_check_time',		# Last consistency check time.
		'L',	'forced_check_int',		# Forced check interval.
		'L',	'creator_os',					# Creator OS: see CO_ below.
		'L',	'ver_major',					# Major version: see MV_ below.
		'S',	'uid_res_blocks',			# UID that can use reserved blocks.
		'S',	'gid_res_blocks',			# GID that can uss reserved blocks.
		# Begin dynamic version fields
		'L',	'first_inode',				# First non-reserved inode in file system.
		'S',	'inode_size',					# Size of each inode.
		'S',	'block_group',				# Block group that this superblock is part of (if backup copy).
		'L',	'compat_flags',				# Compatible feature flags (see CFF_ below).
		'L',	'incompat_flags',			# Incompatible feature flags (see ICF_ below).
		'L',	'ro_flags',						# Read Only feature flags (see ROF_ below).
		'a16',	'fs_id',						# File system ID (UUID or GUID).
		'a16',	'vol_name',					# Volume name.
		'a64',	'last_mnt_path',		# Path where last mounted.
		'L',	'algo_use_bmp',				# Algorithm usage bitmap.
		# Performance hints
		'C',	'file_prealloc_blks',	# Blocks to preallocate for files.
		'C',	'dir_prealloc_blks',	# Blocks to preallocate for directories.
		'S',	'unused1',						# Unused.
		# Journal support
		'a16',	'jrnl_id',					# Joural ID (UUID or GUID).
		'L',	'jrnl_inode',					# Journal inode.
		'L',	'jrnl_device',				# Journal device.
		'L',	'orphan_head',				# Head of orphan inode list.
		'a16',	'hash_seed',				# HTREE hash seed. This is actually L4 (__u32 s_hash_seed[4])
		'C',	'hash_ver',						# Default hash version.
		'C',	'unused2',
		'S',	'unused3',
		'L',	'mount_opts',					# Default mount options.
		'L',	'first_meta_blk_grp',	# First metablock block group.
		'a360',	'reserved'					# Unused.
	])

	SUPERBLOCK_SIG = 0xef53
	SUPERBLOCK_OFFSET = 1024
	SUPERBLOCK_SIZE = 1024
	GDE_SIZE = 32
	INODE_SIZE = 128							# Default inode size.

  # Simpler structure for just validating the presence of a superblock
  SUPERBLOCK_VALIDATE = BinaryStruct.new([
    'x56', nil,
		'S',	'signature',					# Always 0xef53
		'S',	'fs_state',						# File System State: see FSS_ below.
		'S',	'err_method',					# Error Handling Method: see EHM_ below.
	])
  SUPERBLOCK_VALIDATE_SIZE = SUPERBLOCK_VALIDATE.size

	# ////////////////////////////////////////////////////////////////////////////
	# // Class.

	class Superblock

    # Default cache sizes.
    DEF_BLOCK_CACHE_SIZE = 50
    DEF_INODE_CACHE_SIZE = 50

		# File System State.
		FSS_CLEAN				= 0x0001	# File system is clean.
		FSS_ERR					= 0x0002	# File system has errors.
		FSS_ORPHAN_REC	= 0x0004	# Orphan inodes are being recovered.
		# NOTE: Recovered NOT by this software but by the 'NIX kernel.
		# IOW start the VM to repair it.
		FSS_END					= FSS_CLEAN | FSS_ERR | FSS_ORPHAN_REC
		
		# Error Handling Method.
		EHM_CONTINUE		= 1	# No action.
		EHM_RO_REMOUNT	= 2 # Remount file system as read only.
		EHM_PANIC				= 3 # Don't mount? halt? - don't know what this means.
		
		# Creator OS.
		CO_LINUX		= 0	# NOTE: FS creation tools allow setting this value.
		CO_GNU_HURD	= 1	# These values are supposedly defined.
		CO_MASIX		= 2
		CO_FREE_BSD	= 3
		CO_LITES		= 4
		
		# Major Version.
		MV_ORIGINAL	= 0	# NOTE: If version is not dynamic, then values from
		MV_DYNAMIC	= 1	# first_inode on may not be accurate.
		
		# Compatible Feature Flags.
		CFF_PREALLOC_DIR_BLKS	= 0x0001	# Preallocate directory blocks to reduce fragmentation.
		CFF_AFS_SERVER_INODES	= 0x0002	# AFS server inodes exist in system.
		CFF_JOURNAL						= 0x0004	# File system has journal (Ext3).
		CFF_EXTENDED_ATTRIBS	= 0x0008	# Inodes have extended attributes.
		CFF_BIG_PART					= 0x0010	# File system can resize itself for larger partitions.
		CFF_HASH_INDEX				= 0x0020	# Directories use hash index (another modified b-tree).
		CFF_FLAGS							= (CFF_PREALLOC_DIR_BLKS | CFF_AFS_SERVER_INODES | CFF_JOURNAL | CFF_EXTENDED_ATTRIBS | CFF_BIG_PART | CFF_HASH_INDEX)
		
		# Incompatible Feature flags.
		ICF_COMPRESSION				= 0x0001	# Not supported on Linux?
		ICF_FILE_TYPE					= 0x0002	# Directory entries contain file type field.
		ICF_RECOVER_FS				= 0x0004	# File system needs recovery.
		ICF_JOURNAL						= 0x0008	# File system uses journal device.
		ICF_META_BG						= 0x0010	#
		ICF_EXTENTS						= 0x0040	# File system uses extents (ext4)
		ICF_64BIT							= 0x0080	# File system uses 64-bit
		ICF_MMP								= 0x0100	#
		ICF_FLEX_BG						= 0x0200	#
		ICF_EA_INODE					= 0x0400	# EA in inode
		ICF_DIRDATA						= 0x1000	# data in dirent
		ICF_FLAGS             = (ICF_COMPRESSION | ICF_FILE_TYPE | ICF_RECOVER_FS | ICF_JOURNAL | ICF_META_BG | ICF_EXTENTS | ICF_64BIT | ICF_MMP | ICF_FLEX_BG | ICF_EA_INODE | ICF_DIRDATA)
		
		# ReadOnly Feature flags.
		ROF_SPARSE						= 0x0001	# Sparse superblocks & group descriptor tables.
		ROF_LARGE_FILES				= 0x0002	# File system contains large files (over 4G).
		ROF_BTREES						= 0x0004	# Directories use B-Trees (not implemented?).
		ROF_FLAGS							= (ROF_SPARSE | ROF_LARGE_FILES | ROF_BTREES)
		
		# /////////////////////////////////////////////////////////////////////////
		# // initialize
		attr_reader :numGroups, :fsId, :stream, :numBlocks, :numInodes, :fsId, :volName
		attr_reader :sectorSize, :blockSize
		
		@@track_inodes = false

    def self.isSuperblock?(buf)
      sb = SUPERBLOCK_VALIDATE.decode(buf)
      return sb['signature'] == SUPERBLOCK_SIG &&
        sb['fs_state'] <= FSS_END &&
        sb['err_method'] <= EHM_PANIC
    end

		def initialize(stream)
			raise "Ext3::Superblock.initialize: Nil stream" if stream.nil?
			@stream = stream
			
			# Seek, read & decode the superblock structure
			@stream.seek(SUPERBLOCK_OFFSET)
			@sb = SUPERBLOCK.decode(@stream.read(SUPERBLOCK_SIZE))
			
			# Grab some quick facts & make sure there's nothing wrong. Tight qualification.
			raise "Ext3::Superblock.initialize: Invalid signature=[#{@sb['signature']}]" if @sb['signature'] != SUPERBLOCK_SIG
			state = @sb['fs_state']
			raise "Ext3::Superblock.initialize: Invalid file system state" if state > FSS_END
			if state != FSS_CLEAN
				$log.warn("Ext3 file system has errors")        if $log && gotBit?(state, FSS_ERR)
				$log.warn("Ext3 orphan inodes being recovered") if $log && gotBit?(state, FSS_ORPHAN_REC)
			end
			raise "Ext3::Superblock.initialize: Invalid error handling method=[#{@sb['err_method']}]" if @sb['err_method'] > EHM_PANIC
			raise "Ext3::Superblock.initialize: Filesystem has extents (ext4)"  if gotBit?(@sb['incompat_flags'], ICF_EXTENTS)
			
			@blockSize = 1024 << @sb['block_size']

      @block_cache = LruHash.new(DEF_BLOCK_CACHE_SIZE)
      @inode_cache = LruHash.new(DEF_INODE_CACHE_SIZE)
			
			# expose for testing.
			@numBlocks = @sb['num_blocks']
			@numInodes = @sb['num_inodes']
			
      # Inode file size members can't be trusted, so use sector count instead.
      # MiqDisk exposes blockSize, which for our purposes is sectorSize.
      @sectorSize = @stream.blockSize
      
			# Preprocess some members.
			@sb['vol_name'].delete!("\000")
			@sb['last_mnt_path'].delete!("\000")
			@numGroups, @lastGroupBlocks = @sb['num_blocks'].divmod(@sb['blocks_in_group'])
			@numGroups += 1 if @lastGroupBlocks > 0
			@fsId = MiqUUID.parse_raw(@sb['fs_id'])
			@volName = @sb['vol_name']
			@jrnlId = MiqUUID.parse_raw(@sb['jrnl_id'])
		end
		
		# ////////////////////////////////////////////////////////////////////////////
		# // Class helpers & accessors.
		
		def gdt
			@gdt ||= GroupDescriptorTable.new(self)
		end
		
		def isDynamic?
			return @sb['ver_major'] == MV_DYNAMIC
		end
		
		def isNewDirEnt?
			return gotBit?(@sb['incompat_flags'], ICF_FILE_TYPE)
		end
		
		def fragmentSize
			return 1024 << @sb['fragment_size']
		end
		
		def blocksPerGroup
			return @sb['blocks_in_group']
		end
		
		def fragmentsPerGroup
			return @sb['fragments_in_group']
		end
		
		def inodesPerGroup
			return @sb['inodes_in_group']
		end
		
		def inodeSize
			isDynamic? ? @sb['inode_size'] : INODE_SIZE
		end
		
		def freeBytes
			return @sb['unallocated_blocks'] * @blockSize
		end
		
		def blockNumToGroupNum(block)
			raise "Ext3::Superblock.blockNumToGroupNum: block is nil" if block.nil?
			group = (block - @sb['block_group_zero']) / @sb['blocks_in_group']
			offset = block.modulo(@sb['blocks_in_group'])
			return group, offset
		end
		
		def firstGroupBlockNum(group)
			return group * @sb['blocks_in_group'] + @sb['block_group_zero']
		end
		
		def inodeNumToGroupNum(inode)
			return (inode - 1).divmod(inodesPerGroup)
		end
		
		def blockToAddress(block)
			address  = block * @blockSize
			address += (SUPERBLOCK_SIZE + GDE_SIZE * @numGroups) 	if address == SUPERBLOCK_OFFSET
			address
		end
		
		def isValidInode?(inode)
			group, offset = inodeNumToGroupNum(inode)
			gde = gdt[group]
			return gde.inodeAllocBmp[offset]
		end
		
		def isValidBlock?(block)
			group, offset = blockNumToGroupNum(block)
			gde = gdt[group]
			return gde.blockAllocBmp[offset]
		end
		
		# Ignore allocation is for testing only.
		def getInode(inode, ignore_alloc = false)
      unless @inode_cache.has_key?(inode)
  			group, offset = inodeNumToGroupNum(inode)
  			gde = gdt[group]
  			#raise "Inode #{inode} is not allocated" if (not gde.inodeAllocBmp[offset] and not ignore_alloc)
  			@stream.seek(blockToAddress(gde.inodeTable) + offset * inodeSize)
        @inode_cache[inode] = Inode.new(@stream.read(inodeSize))
        $log.info "Inode num: #{inode}\n#{@inode_cache[inode].dump}\n\n" if $log && @@track_inodes
      end
      
      return @inode_cache[inode]
		end
		
		# Ignore allocation is for testing only.
		def getBlock(block, ignore_alloc = false)
			raise "Ext3::Superblock.getBlock: block is nil" if block.nil?
			
      unless @block_cache.has_key?(block)
        if block == 0
          @block_cache[block] = MiqMemory.create_zero_buffer(@blockSize) 
        else
    			group, offset = blockNumToGroupNum(block)
    			gde = gdt[group]
    			#raise "Block #{block} is not allocated" if (not gde.blockAllocBmp[offset] and not ignore_alloc)
    			
    			address = blockToAddress(block)  # This function will read the block into our cache

          @stream.seek(address)
          @block_cache[block] = @stream.read(@blockSize)
  			end
			end
			return @block_cache[block]
		end
		
    def getFeatureStrings()
      out = "Compatible Feature Flags:\n"
      cff = @sb['compat_flags']
      out << "  CFF_PREALLOC_DIR_BLKS\n"  if gotBit?(cff, CFF_PREALLOC_DIR_BLKS)
      out << "  CFF_AFS_SERVER_INODE\n"   if gotBit?(cff, CFF_AFS_SERVER_INODES)
      out << "  CFF_JOURNAL\n"            if gotBit?(cff, CFF_JOURNAL)
      out << "  CFF_EXTENDED_ATTRIBS\n"   if gotBit?(cff, CFF_EXTENDED_ATTRIBS)
      out << "  CFF_BIG_PART\n"           if gotBit?(cff, CFF_BIG_PART)
      out << "  CFF_HASH_INDEX\n"         if gotBit?(cff, CFF_HASH_INDEX)
      extra = cff - (cff & CFF_FLAGS)
      out << "  Extra Flags: 0x%08X\n" % extra if extra != 0
      out << "Incompatible Feature Flags:\n"
      icf = @sb['incompat_flags']
      out << "  ICF_COMPRESSION\n"        if gotBit?(icf, ICF_COMPRESSION)
      out << "  ICF_FILE_TYPE\n"          if gotBit?(icf, ICF_FILE_TYPE)
      out << "  ICF_RECOVER_FS\n"         if gotBit?(icf, ICF_RECOVER_FS)
      out << "  ICF_JOURNAL\n"            if gotBit?(icf, ICF_JOURNAL)
      out << "  ICF_META_BG\n"            if gotBit?(icf, ICF_META_BG)
      out << "  ICF_EXTENTS\n"            if gotBit?(icf, ICF_EXTENTS)
      out << "  ICF_64BIT\n"              if gotBit?(icf, ICF_64BIT)
      out << "  ICF_MMP\n"                if gotBit?(icf, ICF_MMP)
      out << "  ICF_FLEX_BG\n"            if gotBit?(icf, ICF_FLEX_BG)
      out << "  ICF_EA_INODE\n"           if gotBit?(icf, ICF_EA_INODE)
      out << "  ICF_DIRDATA\n"            if gotBit?(icf, ICF_DIRDATA)
      extra = icf - (icf & ICF_FLAGS)
      out << "  Extra Flags: 0x%08X\n" % extra if extra != 0
      out << "Read Only Feature Flags:\n"
      rof = @sb['ro_flags']
      out << "  ROF_SPARSE\n"             if gotBit?(rof, ROF_SPARSE)
      out << "  ROF_LARGE_FILES\n"        if gotBit?(rof, ROF_LARGE_FILES)
      out << "  ROF_BTREES\n"             if gotBit?(rof, ROF_BTREES)
      extra = rof - (rof & ROF_FLAGS)
      out << "  Extra Flags: 0x%08X\n" % extra if extra != 0
      return out
    end
		
		# ////////////////////////////////////////////////////////////////////////////
		# // Utility functions.
		
		def gotBit?(field, bit)
			return field & bit == bit
		end
		
		# Dump object.
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "Number of inodes      : #{@sb['num_inodes']}\n"
			out << "Number of blocks      : #{@sb['num_blocks']}\n"
			out << "Reserved blocks       : #{@sb['reserved_blocks']}\n"
			out << "Unallocated blocks    : #{@sb['unallocated_blocks']}\n"
			out << "Unallocated inodes    : #{@sb['unallocated_inodes']}\n"
			out << "Block group 0         : #{@sb['block_group_zero']}\n"
			out << "Block size            : #{@sb['block_size']} (#{@blockSize} bytes)\n"
			out << "Fragment size         : #{@sb['fragment_size']} (#{self.fragmentSize} bytes)\n"
			out << "Blocks per group      : #{@sb['blocks_in_group']} (#{self.blocksPerGroup} blocks per group)\n"
			out << "Fragments per group   : #{@sb['fragments_in_group']} (#{self.fragmentsPerGroup} fragments per group)\n"
			out << "Inodes per group      : #{@sb['inodes_in_group']} (#{self.inodesPerGroup} inodes per group)\n"
			out << "Last mount time       : #{Time.at(@sb['last_mount_time'])}\n"
			out << "Last write time       : #{Time.at(@sb['last_write_time'])}\n"
			out << "Current mount count   : #{@sb['mount_count']}\n"
			out << "Maximum mount count   : #{@sb['max_mount_count']}\n"
			out << "Signature             : #{@sb['signature']}\n"
			out << "File system state     : #{@sb['fs_state']}\n"
			out << "Error hndling methd   : #{@sb['err_method']}\n"
			out << "Minor version         : #{@sb['ver_minor']}\n"
			out << "Last consistency check: #{Time.at(@sb['last_check_time'])}\n"
			out << "Forced check interval : #{@sb['forced_check_int']} sec\n"
			out << "Creator OS            : #{@sb['creator_os']}\n"
			out << "Major version         : #{@sb['ver_major']}\n"
			out << "UID can use res blocks: #{@sb['uid_res_blocks']}\n"
			out << "GID can use res blocks: #{@sb['gid_res_blocks']}\n"
			if isDynamic?
				out << "First non-res inode   : #{@sb['first_inode']}\n"
				out << "Size of inode         : #{@sb['inode_size']}\n"
				out << "Block group of this SB: #{@sb['block_group']}\n"
				out << "Compatible features   : 0x#{'%08x' % @sb['compat_flags']}\n"
				out << "Incompatible features : 0x#{'%08x' % @sb['incompat_flags']}\n"
				out << "Read Only features    : 0x#{'%08x' % @sb['ro_flags']}\n"
				out << "File system id        : #{@fsId}\n"
				out << "Volume name           : #{@sb['vol_name']}\n"
				out << "Last mount path       : #{@sb['last_mnt_path']}\n"
				out << "Algorithm usage bitmap: 0x#{'%08x' % @sb['algo_use_bmp']}\n"
				out << "Blocks prealloc files : #{@sb['file_prealloc_blks']}\n"
				out << "Blocks prealloc dirs  : #{@sb['dir_prealloc_blks']}\n"
				out << "Journal id            : #{@jrnlId}\n"
				out << "Journal inode         : #{@sb['jrnl_inode']}\n"
				out << "Journal device        : #{@sb['jrnl_device']}\n"
				out << "Orphan inode head     : #{@sb['orphan_head']}\n"
			end
			out << "Number of groups      : #{numGroups}\n"
			out << "Free bytes            : #{freeBytes}\n"
      out << getFeatureStrings
			return out
		end
	end
end #moule Ext3
