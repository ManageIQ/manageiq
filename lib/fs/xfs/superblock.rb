$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'miq-uuid'
require 'stringio'
require 'MiqMemory'
require 'allocation_group'
require 'inode_map'
require 'inode'

require 'rufus/lru'

module XFS
  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions. Linux 2.6.2 from Fedora Core 6.

  SUPERBLOCK = BinaryStruct.new([
    'L>',  'magic_num',          # magic number of the filesystem
    'L>',  'block_size',         # size of a basic unit of space allocation in bytes
    'Q>',  'data_blocks',        # total Number of blocks available for data and metadata
    'Q>',  'realtime_blocks',    # number of blocks on the real-time disk device
    'Q>',  'realtime_extents',   # Number of extents on the real-time disk device
    'a16',  'uuid',              # UUID for the filesystem
    'Q>',  'log_start',          # first block for the journal log if internal (0 if external)
    'Q>',  'root_inode_num',     # root inode number for the filesystem
    'Q>',  'bitmap_inode_num',   # bitmap inode number for real-time extents
    'Q>',  'summary_inode_num',  # summary inode number for real-time bitmap
    'L>',  'realtime_ext_size',  # real-time extent size in blocks
    'L>',  'ag_blocks',          # size of each allocation group in blocks
    'L>',  'ag_count',           # number of allocation groups in the filesystem
    'L>',  'bitmap_blocks',      # number of real-time bitmap blocks
    'L>',  'log_blocks',         # number of blocks for the journaling log
    'S>',  'version_number',     # Filesystem version number
    'S>',  'sector_size',        # underlying disk sector size in bytes
    'S>',  'inode_size',         # size of the inode in bytes
    'S>',  'inodes_per_blk',     # number of inodes per block
    'a12',  'fs_name',           # name for the filesystem
    'C',   'block_size_log',     # log base 2 of block_size
    'C',   'sector_size_log',    # log base 2 of sector_size
    'C',   'inode_size_log',     # log base 2 of inode_size
    'C',   'inodes_per_blk_log', # log base 2 of inodes_per_blk
    'C',   'ag_blocks_log',      # log base 2 of ag_blocks (rounded up)
    'C',   'rt_ext_size_log',    # log base 2 of realtime_ext_size
    'C',   'in_progress',        # flag specifying that the filesystem is being created
    'C',   'inode_max_pct',      # maximum percentage of filesystem space that can be used for inodes
    'Q>',  'inode_count',        # global count for number of inodes allocated on the filesystem
    'Q>',  'inode_free_count',   # global count of free inodes on the filesystem.
    'Q>',  'free_data_blocks',   # global count of free data blocks on the filesystem
    'Q>',  'free_rt_extents',    # global count of free real-time extents on the filesystem
    'Q>',  'user_quota_ino',     # inode number for user quotas
    'Q>',  'group_quota_ino',    # inode number for group quotas
    'S>',  'quota_flags',        # quota flags
    'C',   'misc_flags',         # miscellaneous flags
    'C',   'shared_vers_no',     # shared version number
    'L>',  'inode_alignment',    # inode chunk alignment in blocks
    'L>',  'stripe_unit',        # underlying stripe or raid unit in blocks
    'L>',  'stripe_width',       # underlying stripe or raid width in blocks
    'C',   'dir_block_log',      # log base 2 multiplier that determines the
                                 # granularity of directory block allocations in fsblocks
    'C',   'log_sect_size_log',  # log base 2 of the log subvolume's sector size
    'S>',  'log_sector_size',    # the log's sector size in bytes if the filesystem uses an external log device
    'L>',  'log_stripe_unit_sz', # the log device's stripe or raid unit size.
    'L>',  'features_2',         # add'l version flags if XFS_SUPERBLOCK_VERSION_MOREBITSBIT is set in version_number
                                # version 5 superblock fields start here
    'L>',  'features_compat',
    'L>',  'features_ro_compat',
    'L>',  'features_incompat',
    'L>',  'features_log_incompat',
    'L>',  'superblock_crc',     # superblock crc
    'L>',  'padding',
    'Q>',  'proj_quota_ino',     # inode number for project quotas
    'q>',  'last_write_seq',     # last write sequence
  ])

  SUPERBLOCK_SIZE = 512
  #
  # Block I/O parameterization.	A basic block (BB) is the lowest size of
  # filesystem allocation, and must equal 512.  Length units given to bio
  # routines are in BB's.
  #
  BBSHIFT                    = 9
  BBSIZE                     = 1 << BBSHIFT
  BBMASK                     = BBSIZE - 1
  XFS_INODE_BIG_CLUSTER_SIZE = 8192
  XFS_NBBY                   = 8                   # number of bits in a byte
  XFS_NBBYLOG                = 3                   # log base 2 of number of bits in a byte
  XFS_INODES_PER_CHUNK       = XFS_NBBY * 8
  XFS_DINODE_MIN_LOG         = 8
  XFS_DINODE_MIN_SIZE        = 1 << XFS_DINODE_MIN_LOG

  # ////////////////////////////////////////////////////////////////////////////
  # // Class.

  class Superblock
    DEF_BLOCK_CACHE_SIZE                   = 500
    DEF_CLUSTER_CACHE_SIZE                 = 500
    DEF_INODE_CACHE_SIZE                   = 500
    DEF_AG_CACHE_SIZE                      = 10
    XFS_SUPERBLOCK_MAGIC                   = 0x58465342
    XFS_SUPERBLOCK_VERSION_1               = 1           # 5.3, 6.0.1, 6.1 */
    XFS_SUPERBLOCK_VERSION_2               = 2           # 6.2 - attributes */
    XFS_SUPERBLOCK_VERSION_3               = 3           # 6.2 - new inode version */
    XFS_SUPERBLOCK_VERSION_4               = 4           # 6.2+ - bitmask version */
    XFS_SUPERBLOCK_VERSION_5               = 5           # CRC enabled filesystem */
    XFS_SUPERBLOCK_VERSION_NUMBITS         = 0x000f
    XFS_SUPERBLOCK_VERSION_ALLFBITS        = 0xfff0
    XFS_SUPERBLOCK_VERSION_SASHFBITS       = 0xf000
    XFS_SUPERBLOCK_VERSION_REALFBITS       = 0x0ff0
    XFS_SUPERBLOCK_VERSION_ATTRBIT         = 0x0010
    XFS_SUPERBLOCK_VERSION_NLINKBIT        = 0x0020
    XFS_SUPERBLOCK_VERSION_QUOTABIT        = 0x0040
    XFS_SUPERBLOCK_VERSION_ALIGNBIT        = 0x0080
    XFS_SUPERBLOCK_VERSION_DALIGNBIT       = 0x0100
    XFS_SUPERBLOCK_VERSION_SHAREDBIT       = 0x0200
    XFS_SUPERBLOCK_VERSION_LOGV2BIT        = 0x0400
    XFS_SUPERBLOCK_VERSION_SECTORBIT       = 0x0800
    XFS_SUPERBLOCK_VERSION_EXTFLGBIT       = 0x1000
    XFS_SUPERBLOCK_VERSION_DIRV2BIT        = 0x2000
    XFS_SUPERBLOCK_VERSION_BORGBIT         = 0x4000      # ASCII only case-insens. */
    XFS_SUPERBLOCK_VERSION_MOREBITSBIT     =  0x8000

    XFS_SUPERBLOCK_VERSION_OKSASHFBITS     = XFS_SUPERBLOCK_VERSION_EXTFLGBIT  |
                                             XFS_SUPERBLOCK_VERSION_DIRV2BIT   |
                                             XFS_SUPERBLOCK_VERSION_BORGBIT

    XFS_SUPERBLOCK_VERSION_OKREALFBITS     = XFS_SUPERBLOCK_VERSION_ATTRBIT    |
                                             XFS_SUPERBLOCK_VERSION_NLINKBIT   |
                                             XFS_SUPERBLOCK_VERSION_QUOTABIT   |
                                             XFS_SUPERBLOCK_VERSION_ALIGNBIT   |
                                             XFS_SUPERBLOCK_VERSION_DALIGNBIT  |
                                             XFS_SUPERBLOCK_VERSION_SHAREDBIT  |
                                             XFS_SUPERBLOCK_VERSION_LOGV2BIT   |
                                             XFS_SUPERBLOCK_VERSION_SECTORBIT  |
                                             XFS_SUPERBLOCK_VERSION_MOREBITSBIT

    XFS_SUPERBLOCK_VERSION_OKREALBITS      = XFS_SUPERBLOCK_VERSION_NUMBITS     |
                                             XFS_SUPERBLOCK_VERSION_OKREALFBITS |
                                             XFS_SUPERBLOCK_VERSION_OKSASHFBITS

    #
    # There are two words to hold XFS "feature" bits: the original
    # word, version_number, and features2.  Whenever a bit is set in
    # features2, the feature bit XFS_SUPERBLOCK_VERSION_MOREBITSBIT must be set.
    #
    # These defines represent bits in sb_features2.
    #
    XFS_SUPERBLOCK_VERSION2_REALFBITS      = 0x00ffffff  # Mask: features */
    XFS_SUPERBLOCK_VERSION2_RESERVED1BIT   = 0x00000001
    XFS_SUPERBLOCK_VERSION2_LAZYSBCOUNTBIT = 0x00000002  # Superblk counters */
    XFS_SUPERBLOCK_VERSION2_RESERVED4BIT   = 0x00000004
    XFS_SUPERBLOCK_VERSION2_ATTR2BIT       = 0x00000008  # Inline attr rework */
    XFS_SUPERBLOCK_VERSION2_PARENTBIT      = 0x00000010  # parent pointers */
    XFS_SUPERBLOCK_VERSION2_PROJID32BIT    = 0x00000080  # 32 bit project id */
    XFS_SUPERBLOCK_VERSION2_CRCBIT         = 0x00000100  # metadata CRCs */
    XFS_SUPERBLOCK_VERSION2_FTYPE          = 0x00000200  # inode type in dir */

    XFS_SUPERBLOCK_VERSION2_OKREALFBITS    = XFS_SUPERBLOCK_VERSION2_LAZYSBCOUNTBIT |
                                             XFS_SUPERBLOCK_VERSION2_ATTR2BIT       |
                                             XFS_SUPERBLOCK_VERSION2_PROJID32BIT    |
                                             XFS_SUPERBLOCK_VERSION2_FTYPE
    XFS_SUPERBLOCK_VERSION2_OKSASHFBITS    =  0
    XFS_SUPERBLOCK_VERSION2_OKREALBITS     = XFS_SUPERBLOCK_VERSION2_OKREALFBITS    |
                                             XFS_SUPERBLOCK_VERSION2_OKSASHFBITS

    # /////////////////////////////////////////////////////////////////////////
    # // initialize
    attr_reader :groups_count, :filesystem_id, :stream, :block_count, :inode_count, :volume_name
    attr_reader :sector_size, :block_size, :root_inode, :inode_size, :sb
    attr_reader :ialloc_inos, :ialloc_blks, :agno, :agino, :agbno, :allocation_group_count

    def validate_sb(agno)
      # Grab some quick facts & make sure there's nothing wrong. Tight qualification.
      if @sb['magic_num'] != XFS_SUPERBLOCK_MAGIC
        raise "XFS::Superblock.initialize: Invalid magic number=[#{@sb['magic_num']}] in AG #{agno}"
      end
      unless sb_good_version
        $log.warn "XFS::Superblock.initialize: Bad Superblock version # #{@sb['version_number']} in AG #{agno}"
        $log.warn "Attempting to access filesystem"
      end
      if agno == 0 && @sb['in_progress'] != 0
        $log.warn "XFS::Superblock.initialize: mkfs not completed successfully. Attempting to access filesystem"
      end
    end

    def initialize(stream, agno = 0)
      raise "XFS::Superblock.initialize: Nil stream" if stream.nil?
      @stream = stream

      #
      # Seek, read & decode the superblock structure
      # TODO: FIGURE OUT OFFSET OF SUPERBLOCK for the specified AG number.
      # TODO: @stream.seek(SUPERBLOCK_OFFSET)
      #
      @sb = SUPERBLOCK.decode(@stream.read(SUPERBLOCK_SIZE))
      validate_sb(agno)

      @block_size             = @sb['block_size']

      @block_cache            = LruHash.new(DEF_BLOCK_CACHE_SIZE)
      @cluster_cache          = LruHash.new(DEF_CLUSTER_CACHE_SIZE)
      @inode_cache            = LruHash.new(DEF_INODE_CACHE_SIZE)
      @allocation_group_cache = LruHash.new(DEF_AG_CACHE_SIZE)

      # expose for testing.
      @block_count            = @sb['data_blocks']
      @inode_count            = @sb['inode_count']
      @inode_size             = @sb['inode_size']
      @root_inode             = @sb['root_inode_num']

      # Inode file size members can't be trusted, so use sector count instead.
      # MiqDisk exposes block_size, which for our purposes is sector_size.
      @sector_size            = @stream.blockSize

      # Preprocess some members.
      @sb['fs_name'].delete!("\000")
      @allocation_group_count           = @sb['ag_count']
      @allocation_group_blocks          = @sb['ag_blocks']
      @groups_count, @last_group_blocks = @sb['data_blocks'].divmod(@allocation_group_blocks)
      @groups_count                     += 1 if @last_group_blocks > 0
      @filesystem_id                    = MiqUUID.parse_raw(@sb['uuid'])
      @volume_name                      = @sb['fs_name']
      @ialloc_inos                      = (@sb['inodes_per_blk']..XFS_INODES_PER_CHUNK).max
      @ialloc_blks                      = @ialloc_inos >> @sb['inodes_per_blk_log']
      dumpout                           = dump
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Class helpers & accessors.

    def b_to_bb(bytes)
      (bytes + BBSIZE - 1) >> BBSHIFT
    end

    def b_to_bbt(bytes)
      bytes >> BBSHIFT
    end

    def bb_to_b(bbs)
      bbs << BBSHIFT
    end

    def sb_version_num
      @sb['version_number'] & XFS_SUPERBLOCK_VERSION_NUMBITS
    end

    def sb_version_hascrc
      sb_version_num == XFS_SUPERBLOCK_VERSION_5
    end

    def sb_version_haspquotino
      sb_version_num == XFS_SUPERBLOCK_VERSION_5
    end

    def fragment_size
      1024 << @sb['fragment_size']
    end

    def inode_size
      @sb['inode_size']
    end

    def free_bytes
      @sb['free_data_blocks'] * @block_size
    end

    def ino_mask(k)
      ((1 << k) - 1) & 0xffffffff
    end

    def mask32lo(n)
      (((1 << n) & 0xffffffff) - 1) & 0xffffffff
    end

    def fsb_to_b(fsbno)
      fsbno << @sb['block_size_log']
    end

    def fsb_to_bb(fsbno)
      fsbno << (@sb['block_size_log'] - BBSHIFT)
    end

    def fsb_to_agno(fsbno)
      fsbno >> @sb['ag_blocks_log']
    end

    def fsb_to_agbno(fsbno)
      fsbno & mask32lo(@sb['ag_blocks_log'])
    end

    def fsb_to_daddr(fsbno)
      agb_to_daddr(fsb_to_agno(fsbno), fsb_to_agbno(fsbno))
    end

    def fss_to_bb(sectno)
      sectno << (@sb['sector_size_log'] - BBSHIFT)
    end

    def b_to_fsbt(byte)
      byte >> @sb['block_size_log']
    end

    def ino_to_agno(inode)
      inode >> ino_agino_bits
    end

    def ino_to_agino(inode)
      inode & ino_mask(ino_agino_bits)
    end

    def ino_to_agbno(inode)
      inode >> ino_offset_bits & ino_mask(ino_agbno_bits)
    end

    def ino_to_offset(inode)
      inode & ino_mask(ino_offset_bits)
    end

    def agb_to_fsb(agno, agbno)
      agno << @sb['ag_blocks_log'] | agbno
    end

    def agbno_to_real_block(agno, agbno)
      agno * @allocation_group_blocks + agbno
    end

    def agb_to_daddr(agno, agbno)
      fsb_to_bb(agno * @allocation_group_blocks + agbno)
    end

    def agf_daddr
      1 << (@sb['sector_size_log'] - BBSHIFT)
    end

    def agi_daddr
      2 << (@sb['sector_size_log'] - BBSHIFT)
    end

    def agfl_daddr
      3 << (@sb['sector_size_log'] - BBSHIFT)
    end

    def ag_daddr(agno, d)
      agb_to_daddr(agno, 0) + d
    end

    def ino_to_fsb(inode)
      agb_to_fsb(ino_to_agno(inode), ino_to_agbno(inode))
    end

    def agino_to_ino(agno, inode)
      agno << ino_agino_bits | inode
    end

    def agino_to_agbno(inode)
      inode >> ino_offset_bits
    end

    def agino_to_offset(inode)
      inode & ino_mask(ino_offset_bits)
    end

    def ino_offset_bits
      @sb['inodes_per_blk_log']
    end

    def ino_agbno_bits
      @sb['ag_blocks_log']
    end

    def ino_agino_bits
      @sb['inodes_per_blk_log'] + @sb['ag_blocks_log']
    end

    def offbno_to_agino(block, offset)
      (block << @sb['inodes_per_blk_log']) | offset
    end

    def sb_version_hasalign
      (sb_version_num == XFS_SUPERBLOCK_VERSION_5) ||
      ((sb_version_num >= XFS_SUPERBLOCK_VERSION_4) &&
      (@sb['version_number'] & XFS_SUPERBLOCK_VERSION_ALIGNBIT))
    end

    def inode_align_mask
      if sb_version_hasalign &&
         @sb['inode_alignment'] >> b_to_fsbt(XFS_INODE_BIG_CLUSTER_SIZE)
        return @sb['inode_alignment']
      else
        return 0
      end
    end

    def sb_good_version_4(sb)
      if (sb['version_number'] & ~XFS_SUPERBLOCK_VERSION_OKREALBITS) ||
         ((sb['version_number'] & XFS_SUPERBLOCK_VERSION_MOREBITSBIT) &&
         (sb['features_2'] & ~XFS_SUPERBLOCK_VERSION2_OKREALBITS))
        return 0
      end
      return 0 if sb['shared_vers_no'] > XFS_SB_MAX_SHARED_VN
      1
    end

    def sb_good_version
      #
      # We always support version 1-3
      #
      if sb_version_num >= XFS_SUPERBLOCK_VERSION_1 &&
         sb_version_num <= XFS_SUPERBLOCK_VERSION_3
        return 1
      end
      #
      # We support version 4 if all feature bits are supported
      #
      if sb_version_num == XFS_SUPERBLOCK_VERSION_4
        return sb_good_version_4(@sb)
      end
      return 1 if sb_version_num == XFS_SUPERBLOCK_VERSION_5
    end

    def inode_cluster_size
      cluster_size = XFS_INODE_BIG_CLUSTER_SIZE
      if sb_version_hascrc
        new_size = cluster_size
        new_size *= inode_size / XFS_DINODE_MIN_SIZE
        if @sb['inode_alignment'] >= b_to_fsbt(new_size)
          cluster_size = new_size
        end
      end
      cluster_size
    end

    def icluster_size_fsb
      cluster_size = inode_cluster_size
      return 1 if @block_size > cluster_size
      cluster_size >> @sb['block_size_log']
    end

    def get_ag(agno)
      unless @allocation_group_cache.key?(agno)
        blk_num  = ag_daddr(agno, agf_daddr)
        @stream.seek(fsb_to_b(blk_num))
        @allocation_group_cache[agno] = AllocationGroup.new(@stream, agno, @sb)
      end
      @allocation_group_cache[agno]
    end

    def get_agi(agno)
      get_ag(agno).agi
    end

    def get_agf(agno)
      get_ag(agno).agf
    end

    def get_agblock(agno)
      get_ag(agno).agblock
    end

    def inode_btree_record
      InodeBtreeRecord.new(cursor)
    end

    def get_inode(inode)
      unless @inode_cache.key?(inode)
        inode_map = InodeMap.new(inode, self)
        if icluster_size_fsb == 1
          buf = get_block(inode_map.inode_blkno)
        else
          buf = get_cluster(inode_map.inode_blkno)
        end
        @inode_cache[inode] = Inode.new(buf, inode_map.inode_boffset, self, inode)
      end

      @inode_cache[inode]
    end

    def get_cluster(block)
      raise "XFS::Superblock.get_cluster: block is nil" if block.nil?
      @cluster_cache[block] = MiqMemory.create_zero_buffer(@block_size * icluster_size_fsb) if block == 0
      unless @cluster_cache.key?(block)
        @stream.seek(fsb_to_b(block))
        @cluster_cache[block] = @stream.read(@block_size * icluster_size_fsb)
      end
      @cluster_cache[block]
    end

    def get_block(block)
      raise "XFS::Superblock.get_block: block is nil" if block.nil?
      @block_cache[block] = MiqMemory.create_zero_buffer(@block_size) if block == 0
      unless @block_cache.key?(block)
        @stream.seek(fsb_to_b(block))
        @block_cache[block] = @stream.read(@block_size)
      end
      @block_cache[block]
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Utility functions.

    def got_bit?(field, bit)
      field & bit == bit
    end

    # Dump object.
    def dump
      out = "\#<#{self.class}:0x#{format('%08x', object_id)}>\n"
      out << "Magic number            : #{format('%0x', @sb['magic_num'])}\n"
      out << "Block size              : #{@sb['block_size']} (#{@block_size} bytes)\n"
      out << "Number of blocks        : #{@sb['data_blocks']}\n"
      out << "Real-time blocks        : #{@sb['realtime_blocks']}\n"
      out << "Real-time extents       : #{@sb['realtime_extents']}\n"
      out << "UUID                    : #{@filesystem_id}\n"
      out << "Journal Log Start block : #{@sb['log_start']}\n"
      out << "Root Inode #            : #{@sb['root_inode_num']}\n"
      out << "RealTime Bitmap Inode#  : #{@sb['bitmap_inode_num']}\n"
      out << "RealTime Summary Inode# : #{@sb['summary_inode_num']}\n"
      out << "RT Extent Size (Blocks) : #{@sb['realtime_ext_size']}\n"
      out << "Alloc Group Size        : #{@sb['ag_blocks']}\n"
      out << "# of Alloc Groups       : #{@sb['ag_count']}\n"
      out << "# of RT Bitmap Blocks   : #{@sb['bitmap_blocks']}\n"
      out << "# of Journal Log Blocks : #{@sb['log_blocks']}\n"
      out << "Filesystem Version #    : #{sb_version_num}\n"
      out << "Disk Sector Size        : #{@sb['sector_size']} bytes\n"
      out << "Inode Size              : #{@sb['inode_size']} bytes\n"
      out << "Inodes Per Block        : #{@sb['inodes_per_blk']}\n"
      out << "Filesystem Name         : #{@sb['fs_name']}\n"
      out << "Log Base2 of Block size : #{@sb['block_size_log']}\n"
      out << "Log Base2 of Sector size : #{@sb['sector_size_log']}\n"
      out << "Log Base2 of Inode size : #{@sb['inode_size_log']}\n"
      out << "Log Base2 of Inodes/Blk : #{@sb['inodes_per_blk_log']}\n"
      out << "Log Base2 AllocGrp size : #{@sb['ag_blocks_log']}\n"
      out << "Log Base2 RT Extent sz  : #{@sb['rt_ext_size_log']}\n"
      out << "In Progress Flag        : #{@sb['in_progress']}\n"
      out << "Inode Space Max Percent : #{@sb['inode_max_pct']}\n"
      out << "Inodes Allocated on FS  : #{@sb['inode_count']}\n"
      out << "Free Inodes on FS       : #{@sb['inode_free_count']}\n"
      out << "Free Data Blocks on FS  : #{@sb['free_data_blocks']}\n"
      out << "Free RT Extents on FS   : #{@sb['free_rt_extents']}\n"
      out << "Inode # for User Quotas : #{@sb['user_quota_ino']}\n"
      out << "Inode # for Grp Quotas  : #{@sb['group_quota_ino']}\n"
      out << "Quota Flags             : #{@sb['quota_flags']}\n"
      out << "Miscellaneous Flags     : #{@sb['misc_flags']}\n"
      out << "Shared Version #        : #{@sb['shared_vers_no']}\n"
      out << "Inode Chunk Alignment   : #{@sb['inode_alignment']}\n"
      out << "Stripe or Raid Unit     : #{@sb['stripe_unit']}\n"
      out << "Stripe or Raid Width    : #{@sb['stripe_width']}\n"
      out << "Log Base2 Dir Block     : #{@sb['dir_block_log']}\n"
      out << "Log Base2 Log Sect Size : #{@sb['log_sect_size_log']}\n"
      out << "External Log Sect Size  : #{@sb['log_sector_size']}\n"
      out << "Log Device Stripe Size  : #{@sb['log_stripe_unit_sz']}\n"
      out << "Additional Version Flgs : #{@sb['features_2']}\n"
      out << "Compat Features         : #{@sb['features_compat']}\n"
      out << "R/O Compat Features     : #{@sb['features_ro_compat']}\n"
      out << "Incompat Features       : #{@sb['features_incompat']}\n"
      out << "Log Incompat Features   : #{@sb['features_log_incompat']}\n"
      out << "Superblock CRC          : #{@sb['superblock_crc']}\n"
      out << "Inode # Project Quotas  : #{@sb['proj_quota_ino']}\n"
      out << "Last Write Sequence     : #{@sb['last_write_seq']}\n"
      out
    end
  end # class Superblock
end # module XFS
