$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'MiqMemory'
require 'more_core_extensions/all'
require 'superblock'
require 'bmap_btree_record'
require 'bmap_btree_block'
require 'bmap_btree_root_node'

module XFS
  TIMESTAMP = BinaryStruct.new([
    'I',  'seconds',           # timestamp seconds
    'I',  'nanoseconds',       # timestamp nanoseconds
  ])

  INODE = BinaryStruct.new([
    'S>',  'magic',             # Inode Magic Number
    'S>',  'file_mode',         # Mode and Type of file
    'C',   'version',           # Inode Version
    'C',   'format',            # Format of Data Fork Data
    'S>',  'old_num_links',     # Old Number of Links to File
    'I>',  'uid',               # Owner's User Id
    'I>',  'gid',               # Owner's Group Id
    'I>',  'num_links',         # Number of Links to File
    'S>',  'projid_low',        # Lower Part of Owner's Project Id
    'S>',  'projid_high',       # Higher Part of Owner's Project Id
    'a6',  'pad',               # Unused, Zeroed Space
    'S>',  'flush_iterator',    # Incremented on Flush
    'I>',  'atime_secs',        # time last accessed seconds
    'I>',  'atime_nsecs',       # time last accessed nanoseconds
    'I>',  'mtime_secs',        # time last modified seconds
    'I>',  'mtime_nsecs',       # time last modified nanoseconds
    'I>',  'ctime_secs',        # time created / inode modified seconds
    'I>',  'ctime_nsecs',       # time created / inode modified nanoseconds
    'Q>',  'size',              # number of bytes in file
    'Q>',  'nblocks',           # Number of direct & btree blocks used
    'I>',  'extent_size',       # Basic/Minimum extent size for file
    'I>',  'num_extents',       # Number of extents in data fork
    'S>',  'attr_num_extents',  # Number of extents in attribute fork
    'C',   'attr_fork_offset',  # Attribute Fork Offset, <<3 for 64b align
    'c',   'attr_fork_format',  # Format of Attribute Fork's Data
    'I>',  'dmig_event_mask',   # DMIG event mask
    'S>',  'dmig_state_info',   # DMIG state info
    'S>',  'flags',             # random flags, XFS_DIFLAG_...
    'I>',  'gen_num',           # generation number
    'I>',  'next_unlinked',     # agi unlinked list ptr
  ])

  EXTENDED_INODE = BinaryStruct.new([
    'S>',  'magic',             # Inode Magic Number
    'S>',  'file_mode',         # Mode and Type of file
    'C',   'version',           # Inode Version
    'C',   'format',            # Format of Data Fork Data
    'S>',  'old_num_links',     # Old Number of Links to File
    'I>',  'uid',               # Owner's User Id
    'I>',  'gid',               # Owner's Group Id
    'I>',  'num_links',         # Number of Links to File
    'S>',  'projid_low',        # Lower Part of Owner's Project Id
    'S>',  'projid_high',       # Higher Part of Owner's Project Id
    'a6',  'pad',               # Unused, Zeroed Space
    'S>',  'flush_iterator',    # Incremented on Flush
    'I>',  'atime_secs',        # time last accessed seconds
    'I>',  'atime_nsecs',       # time last accessed nanoseconds
    'I>',  'mtime_secs',        # time last modified seconds
    'I>',  'mtime_nsecs',       # time last modified nanoseconds
    'I>',  'ctime_secs',        # time created / inode modified seconds
    'I>',  'ctime_nsecs',       # time created / inode modified nanoseconds
    'Q>',  'size',              # number of bytes in file
    'Q>',  'nblocks',           # Number of direct & btree blocks used
    'I>',  'extent_size',       # Basic/Minimum extent size for file
    'I>',  'num_extents',       # Number of extents in data fork
    'S>',  'attr_num_extents',  # Number of extents in attribute fork
    'C',   'attr_fork_offset',  # Attribute Fork Offset, <<3 for 64b align
    'c',   'attr_fork_format',  # Format of Attribute Fork's Data
    'I>',  'dmig_event_mask',   # DMIG event mask
    'S>',  'dmig_state_info',   # DMIG state info
    'S>',  'flags',             # random flags, XFS_DIFLAG_...
    'I>',  'gen_num',           # generation number
    'I>',  'next_unlinked',     # agi unlinked list ptr
    'I>',  'crc',               # CRC of the inode
    'Q>',  'change_count',      # number of attribute changes
    'Q>',  'lsn',               # flush sequence
    'Q>',  'flags2',            # more random flags
    'a16', 'pad2',              # more padding for future expansion
    'I>',  'crtime_secs',       # time created seconds
    'I>',  'crtime_nsecs',      # time created nanoseconds
    'Q>',  'inode_number',      # inode number
    'a16', 'uuid',              # UUID of the filesystem
  ])

  SIZEOF_INODE = INODE.size
  SIZEOF_EXTENDED_INODE = EXTENDED_INODE.size

  SYM_LNK_SIZE          = 60
  MAX_READ              = 4_294_967_296
  DEFAULT_BLOCK_SIZE    = 1024

  # ////////////////////////////////////////////////////////////////////////////
  # // Class.

  class Inode
    XFS_DINODE_MAGIC             = 0x494e
    # Values for Inode flags field
    XFS_DIFLAG_REALTIME_BIT      = 0	# file's blocks come from rt area
    XFS_DIFLAG_PREALLOC_BIT      = 1	# file space has been preallocated
    XFS_DIFLAG_NEWRTBM_BIT       = 2	# for rtbitmap inode, new format
    XFS_DIFLAG_IMMUTABLE_BIT     = 3	# inode is immutable
    XFS_DIFLAG_APPEND_BIT        = 4	# inode is append-only
    XFS_DIFLAG_SYNC_BIT          = 5	# inode is written synchronously
    XFS_DIFLAG_NOATIME_BIT       = 6	# do not update atime
    XFS_DIFLAG_NODUMP_BIT        = 7	# do not dump
    XFS_DIFLAG_RTINHERIT_BIT     = 8	# create with realtime bit set
    XFS_DIFLAG_PROJINHERIT_BIT   = 9	# create with parents projid
    XFS_DIFLAG_NOSYMLINKS_BIT    = 10	# disallow symlink creation
    XFS_DIFLAG_EXTSIZE_BIT       = 11	# inode extent size allocator hint
    XFS_DIFLAG_EXTSZINHERIT_BIT  = 12	# inherit inode extent size
    XFS_DIFLAG_NODEFRAG_BIT      = 13	# do not reorganize/defragment
    XFS_DIFLAG_FILESTREAM_BIT    = 14  # use filestream allocator
    XFS_DIFLAG_REALTIME          = 1 << XFS_DIFLAG_REALTIME_BIT
    XFS_DIFLAG_PREALLOC          = 1 << XFS_DIFLAG_PREALLOC_BIT
    XFS_DIFLAG_NEWRTBM           = 1 << XFS_DIFLAG_NEWRTBM_BIT
    XFS_DIFLAG_IMMUTABLE         = 1 << XFS_DIFLAG_IMMUTABLE_BIT
    XFS_DIFLAG_APPEND            = 1 << XFS_DIFLAG_APPEND_BIT
    XFS_DIFLAG_SYNC              = 1 << XFS_DIFLAG_SYNC_BIT
    XFS_DIFLAG_NOATIME           = 1 << XFS_DIFLAG_NOATIME_BIT
    XFS_DIFLAG_NODUMP            = 1 << XFS_DIFLAG_NODUMP_BIT
    XFS_DIFLAG_RTINHERIT         = 1 << XFS_DIFLAG_RTINHERIT_BIT
    XFS_DIFLAG_PROJINHERIT       = 1 << XFS_DIFLAG_PROJINHERIT_BIT
    XFS_DIFLAG_NOSYMLINKS        = 1 << XFS_DIFLAG_NOSYMLINKS_BIT
    XFS_DIFLAG_EXTSIZE           = 1 << XFS_DIFLAG_EXTSIZE_BIT
    XFS_DIFLAG_EXTSZINHERIT      = 1 << XFS_DIFLAG_EXTSZINHERIT_BIT
    XFS_DIFLAG_NODEFRAG          = 1 << XFS_DIFLAG_NODEFRAG_BIT
    XFS_DIFLAG_FILESTREAM        = 1 << XFS_DIFLAG_FILESTREAM_BIT

    XFS_DIFLAG_ANY = (XFS_DIFLAG_REALTIME | XFS_DIFLAG_PREALLOC | XFS_DIFLAG_NEWRTBM |
                      XFS_DIFLAG_IMMUTABLE | XFS_DIFLAG_APPEND | XFS_DIFLAG_SYNC |
                      XFS_DIFLAG_NOATIME | XFS_DIFLAG_NODUMP | XFS_DIFLAG_RTINHERIT |
                      XFS_DIFLAG_PROJINHERIT | XFS_DIFLAG_NOSYMLINKS | XFS_DIFLAG_EXTSIZE |
                      XFS_DIFLAG_EXTSZINHERIT | XFS_DIFLAG_NODEFRAG | XFS_DIFLAG_FILESTREAM)

    XFS_DI_MAX_FLUSH = 0xffff

    # Bits 0 to 8 of file mode.
    PF_O_EXECUTE  = 0x0001  # owner execute
    PF_O_WRITE    = 0x0002  # owner write
    PF_O_READ     = 0x0004  # owner read
    PF_G_EXECUTE  = 0x0008  # group execute
    PF_G_WRITE    = 0x0010  # group write
    PF_G_READ     = 0x0020  # group read
    PF_U_EXECUTE  = 0x0040  # user execute
    PF_U_WRITE    = 0x0080  # user write
    PF_U_READ     = 0x0100  # user read

    # For accessor convenience.
    MSK_PERM_OWNER = (PF_O_EXECUTE | PF_O_WRITE | PF_O_READ)
    MSK_PERM_GROUP = (PF_G_EXECUTE | PF_G_WRITE | PF_G_READ)
    MSK_PERM_USER  = (PF_U_EXECUTE | PF_U_WRITE | PF_U_READ)

    # Bits 9 to 11 of file mode.
    DF_STICKY     = 0x0200
    DF_SET_GID    = 0x0400
    DF_SET_UID    = 0x0800

    # Bits 12 to 15 of file mode.
    FM_FIFO       = 0x1000  # fifo device (pipe)
    FM_CHAR       = 0x2000  # char device
    FM_DIRECTORY  = 0x4000  # directory
    FM_BLOCK_DEV  = 0x6000  # block device
    FM_FILE       = 0x8000  # regular file
    FM_SYM_LNK    = 0xa000  # symbolic link
    FM_SOCKET     = 0xc000  # socket device

    # For accessor convenience.
    MSK_FILE_MODE = 0xf000
    MSK_IS_DEV    = (FM_FIFO | FM_CHAR | FM_BLOCK_DEV | FM_SOCKET)

    # For Data Fork Data Format
    XFS_DINODE_FMT_DEV     = 0  # Device Type
    XFS_DINODE_FMT_LOCAL   = 1  # Bulk Data
    XFS_DINODE_FMT_EXTENTS = 2  # xfs_bmbt_rec
    XFS_DINODE_FMT_BTREE   = 3  # xfs_bmdr_block
    XFS_DINODE_FMT_UUID    = 4  # uuid

    XFS_DATA_FORK = 0
    XFS_ATTR_FORK = 1

    def dinode_good_version(version)
      version >= 1 && version <= 3
    end

    def dinode_size(version)
      if version == 3
        SIZEOF_EXTENDED_INODE
      else
        SIZEOF_INODE
      end
    end

    def dfork_q
      @in['attr_fork_offset'] != 0
    end

    def dfork_boff
      @in['attr_fork_offset'] << 3
    end

    def dfork_dsize
      dfork_q ? dfork_boff : litino
    end

    def dfork_asize
      dfork_q ? litino - dfork_boff : 0
    end

    def dfork_size(which_fork)
      which_fork == XFS_DATA_FORK ? dfork_dsize : dfork_asize
    end

    def dfork_dptr
      @disk_buf[dinode_size(@version)..@sb.inode_size]
    end

    def dfork_aptr
      dfork_dptr + dfork_boff
    end

    def litino
      @sb.inodeSize - dinode_size(@version)
    end

    attr_reader :mode, :flags, :length, :disk_buf, :version, :inode_number, :sb, :data_method
    attr_accessor :data_fork, :attribute_fork

    def valid_inode?
      raise "XFS::Inode: Invalid Magic Number for inode #{inode_number}"  unless @in['magic'] == XFS_DINODE_MAGIC
      raise "XFS::Inode: Invalid Inode Version for inode #{inode_number}" unless dinode_good_version(@in['version'])
      true
    end

    def inode_format
      if @format    == XFS_DINODE_FMT_LOCAL
        data_method    = :local
        @symlink          = read_shortform(@length) if symlink?
      elsif @format == XFS_DINODE_FMT_EXTENTS
        data_method    = :extents
      else
        data_method    = :btree
      end
      data_method
    end

    def initialize(buf, offset, superblock, inode_number)
      raise "XFS::Inode: Nil buffer for inode #{inode_number}" if buf.nil?
      @sb               = superblock
      @inode_number     = inode_number
      if @sb.inode_size < SIZEOF_EXTENDED_INODE
        @in             = INODE.decode(buf[offset..(offset + SIZEOF_INODE)])
      else
        @in             = EXTENDED_INODE.decode(buf[offset..(offset + SIZEOF_EXTENDED_INODE)])
      end
      valid_inode? || return

      @mode             = @in['file_mode']
      @flags            = @in['flags']
      @version          = @in['version']
      @length           = @in['size']
      @format           = @in['format']
      @block_offset     = 1
      @data_method      = inode_format
      if @data_method   == :local
        @symlink          = read_shortform(@length) if symlink?
      end
      @disk_buf         = buf
      rewind
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Method for data access
    def rewind
      @pos = 0
    end

    def seek(offset, method = IO::SEEK_SET)
      @pos = case method
             when IO::SEEK_SET then offset
             when IO::SEEK_CUR then @pos + offset
             when IO::SEEK_END then length - offset
      end
      @pos = 0           if @pos < 0
      @pos = length if @pos > length
      @pos
    end

    def read(nbytes = length)
      raise "XFS::Inode.read: Can't read 4G or more at a time (use a smaller read size)" if nbytes >= MAX_READ
      return nil if @pos >= length

      nbytes = length - @pos if @pos + nbytes > length
      return read_shortform(nbytes) if @data_method == :local

      # get data.
      start_block, start_byte, nblocks = pos_to_block(@pos, nbytes)
      out = read_blocks(start_block, nblocks)
      @pos += nbytes
      out[start_byte, nbytes]
    end

    def write(buf, _len = buf.length)
      raise "XFS::Inode.write: Write functionality is not yet supported on XFS."
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Class helpers & accessors.

    def directory?
      mode_set?(FM_DIRECTORY)
    end

    def file?
      mode_set?(FM_FILE)
    end

    def device?
      (@mode & MSK_IS_DEV) > 0
    end

    def symlink?
      mode_set?(FM_SYM_LNK)
    end

    def access_time
      @access_time ||= Time.at(@in['atime'])
    end

    def create_time
      @create_time ||= Time.at(@in['ctime'])
    end

    def modification_time
      @modification_time ||= Time.at(@in['mtime'])
    end

    def d_time
      @d_time ||= Time.at(@in['dtime'])
    end

    def permissions
      @permissions ||= @in['file_mode'] & (MSK_PERM_OWNER | MSK_PERM_GROUP | MSK_PERM_USER)
    end

    def owner_permissions
      @owner_permissions ||= @in['file_mode'] & MSK_PERM_OWNER
    end

    def group_permissions
      @group_permissions ||= @in['file_mode'] & MSK_PERM_GROUP
    end

    def user_permissions
      @user_permissions  ||= @in['file_mode'] & MSK_PERM_USER
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Utility functions.

    def file_mode_to_file_type
      @@FM2FT[@mode & MSK_FILE_MODE]
    end

    def mode_set?(bit)
      (@mode  & bit) == bit
    end

    def flag_set?(bit)
      (@flags & bit) == bit
    end

    def dump
      out = "\#<#{self.class}:0x#{format('%08x', object_id)}>\n"
      out += "Inode Number : #{@inode_number}\n"
      out += "File mode    : 0x#{format('%04x', @in['file_mode'])}\n"
      out += "UID          : #{@in['uid']}\n"
      out += "Size         : #{@in['size']}\n"
      out += "ATime Secs/NSecs: #{@in['atime_secs']}/#{@in['atime_nsecs']}\n"
      out += "CTime Secs/NSecs: #{@in['ctime_secs']}/#{@in['ctime_nsecs']}\n"
      out += "MTime Secs/NSecs: #{@in['mtime_secs']}/#{@in['mtime_nsecs']}\n"
      out += "DTime        : #{@in['dTime']}\n"
      out += "GID          : #{@in['gid']}\n"
      out += "Link count   : #{@in['num_links']}\n"
      out += "Old Link cnt : #{@in['old_num_links']}\n"
      out += "Block count  : #{@in['nblocks']}\n"
      out += "Extent size  : #{@in['extent_size']}\n"
      out += "Num extents  : #{@in['num_extents']}\n"
      out += "Data Fork Fmt : #{@data_method}\n"
      out += "Attr Fork Exts: #{@in['attr_num_extents']}\n"
      out += "Attr Fork Off : #{@in['attr_fork_offset']}\n"
      out += "Attr Fork Fmt : #{@in['attr_fork_format']}\n"
      out += "Flags        : #{format('%04x', @in['flags'])}\n"
      out += "Version      : #{@in['version']}\n"
      out += "Flush Iter   : #{@in['flush_iterator']}\n"
      out += "Generation   : #{@in['gen_num']}\n"
      out
    end

    private

    def read_shortform(len)
      unless self.isDir? || self.isSymLink?
        raise "XFS::Inode.read: Invalid ShortForm Directory for inode #{@inode_number}"
      end
      if @pos + len > @sb.inodeSize
        raise "XFS::Inode.read_shortform: Invalid length #{len} for Shortform Inode #{@inode_number}"
      end
      fork = dfork_dptr
      data = fork[@pos..(@pos + len - 1)]
      @pos += len
      data
    end

    # NB: pos is 0-based, while len is 1-based
    def pos_to_block(pos, len)
      start_block, start_byte = pos.divmod(@sb.blockSize)
      end_block, _end_byte = (pos + len - 1).divmod(@sb.blockSize)
      nblocks = end_block - start_block + 1
      return start_block, start_byte, nblocks
    end

    def read_blocks(startBlock, nblocks = 1)
      out = MiqMemory.create_zero_buffer(nblocks * @sb.blockSize)
      dbp_len = data_block_pointers.length
      raise "XFS::Inode.read_blocks: startBlock=<#{startBlock}> is greater than #{dbp_len}" if startBlock > dbp_len - 1
      1.upto(nblocks) do |i|
        block_index = startBlock + i - 1
        dbp_len = data_block_pointers.length
        if block_index > dbp_len - 1
          raise "XFS::Inode.read_blocks: block_index=<#{block_index}> is greater than #{dbp_len}"
        end
        block = data_block_pointers[block_index]
        data  = @sb.get_block(block)
        out[(i - 1) * @sb.blockSize, @sb.blockSize] = data
      end
      out
    end

    #
    # This method is used for both extents and BTree leaf nodes
    #
    def bmap_btree_record_to_block_pointers(record, block_pointers_length)
      block_pointers = []
      # Fill in the missing blocks with 0-blocks
      block_pointers << 0 while (block_pointers_length + block_pointers.length) < record.start_offset
      1.upto(record.block_count) { |i| block_pointers << record.start_block + i - 1 }
      @block_offset += record.block_count
      block_pointers
    end

    def expected_blocks
      @expected_blocks ||= begin
        quotient, remainder = length.divmod(@sb.blockSize)
        quotient + ( (remainder > 0) ? 1 : 0)
      end
    end

    def block_pointers_via_bmap_btree_block_leaf(data, block_pointers_length, number_records)
      block_pointers = []
      if (block_pointers_length + block_pointers.length) < expected_blocks
        1.upto(number_records) do |i|
          bmap_btree_record = BmapBTreeRecord.new(data[(SIZEOF_BMAP_BTREE_REC * (i - 1))..(SIZEOF_BMAP_BTREE_REC * i)])
          $log.info "Bmap Btree Record for Inode: #{inode_number}\n#{bmap_btree_record.dump}\n\n" if $log
          if (block_pointers_length + block_pointers.length) < expected_blocks
            block_pointers.concat bmap_btree_record_to_block_pointers(bmap_btree_record, block_pointers.length)
          end
        end
      end
      block_pointers
    end

    def block_pointers_via_bmap_btree_block(block_number, block_pointers_length)
      block_pointers = []
      if block_pointers_length < expected_blocks
        data           = @sb.get_block(block_number)
        btree_block    = BmapBTreeBlock.new(data, @sb)
        if btree_block.level == 0
          block_pointers.concat block_pointers_via_bmap_btree_block_leaf(data[btree_block.header_size..-1],
                                                                         block_pointers.length,
                                                                         btree_block.number_records)
        else
          block_pointers.concat block_pointers_via_bmap_btree_block_node(btree_block[btree_block.header_size..-1],
                                                                         block_pointers.length,
                                                                         btree_block.number_records)
        end
      end
      block_pointers
    end

    def block_pointers_via_btree
      block_pointers = []
      fork = dfork_dptr
      root_node = BmapBTreeRootNode.new(fork, self)
      root_node.blocks.each do |block_number|
        block_pointers.concat block_pointers_via_bmap_btree_block(block_number, block_pointers.length)
      end
      block_pointers
    end

    def extent_to_block_pointers(extent, bplen)
      block_pointers = []
      # Fill in the missing blocks with 0-blocks
      block_pointers << 0 while (bplen + block_pointers.length) < extent.start_offset
      @block_offset.upto(extent.block_count) { |i| block_pointers << extent.start_block + i - 1 }
      @block_offset += extent.block_count
      block_pointers
    end

    def block_pointers_via_extents
      block_pointers = []
      fork = dfork_dptr
      return block_pointers if @in['num_extents'] == 0
      1.upto(@in['num_extents']) do |i|
        bmap_btree_record = BmapBTreeRecord.new(fork[(SIZEOF_BMAP_BTREE_REC * (i - 1))..(SIZEOF_BMAP_BTREE_REC * i)])
        $log.info "Bmap Btree Record for Inode: #{inode_number}\n#{bmap_btree_record.dump}\n\n" if $log
        block_pointers.concat extent_to_block_pointers(bmap_btree_record, block_pointers.length)
      end
      block_pointers
    end

    def read_block_pointers(block)
      @sb.get_block(block).unpack('L*')
    end

    def data_block_pointers
      if @data_block_pointers.nil?
        @data_block_pointers = block_pointers_via_extents          if @data_method == :extents
        @data_block_pointers = block_pointers_via_btree            if @data_method == :btree
        dbp_len = @data_block_pointers.length
        if expected_blocks != dbp_len
          raise "XFS::Inode.block_pointers: Block Pointers <#{dbp_len}> does not match Expected <#{expected_blocks}>"
        end
      end
      @data_block_pointers
    end
  end # Class Inode
end # Module XFS
