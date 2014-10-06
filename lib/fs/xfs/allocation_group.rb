$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'miq-uuid'
require 'stringio'
require 'MiqMemory'
require 'superblock'

require 'rufus/lru'

module XFS
  # ////////////////////////////////////////////////////////////////////////////

  AG_FREESPACE = BinaryStruct.new([
    #  Common allocation group header information
    'I>',  'magic_num',          # magic number of the filesystem
    'I>',  'version_num',        # header version
    'I>',  'seq_no',             # sequence # starting from 0
    'I>',  'length',             # size in blocks of a.g.
    #  Freespace Information
    #
    'I>2', 'root_blocks',        # Root Blocks
    'I>',  'spare0',             # spare field
    'I>2', 'btree_levels',       # btree levels
    'I>',  'spare1',             # spare field
    'I>',  'fl_first',           # first freelist block's index
    'I>',  'fl_last',            # last freelist block's index
    'I>',  'fl_count',           # count of blocks in freelist
    'I>',  'free_blocks',        # total free blocks
    'L>',  'longest',            # longest free space
    'L>',  'btree_blocks',       # # of blocks held in alloc group free btrees
    'a16', 'uuid',               # Filesystem uuid
    #
    # Reserve some contiguous space for future logged fields before we add
    # the unlogged fields.  This makes the range logging via flags and
    # structure offsets much simpler.
    #
    'Q>16', 'spare64',           # underlying disk sector size in bytes
    #
    # Unlogged fields, written during buffer writeback.
    #
    'Q>',  'last_write_seq',     # last write sequence
    'I>',  'crc',                # CRC of alloc group free space sector
    'I>',  'spare2',             # name for the filesystem
  ])

  AG_INODEINFO = BinaryStruct.new([
    #  Common allocation group header information
    'I>',  'magic_num',          # magic number of the filesystem
    'I>',  'version_num',        # header version
    'I>',  'seq_no',             # sequence # starting from 0
    'I>',  'length',             # size in blocks of a.g.
    #
    #  Inode information
    #  Inodes are mapped by interpretting the inode number, so no
    #  mapping data is needed here.
    #
    'I>',  'count',              # count of allocated inodes
    'I>',  'root',               # root of inode btree
    'I>',  'level',              # levels in inode btree
    'I>',  'free_count',         # number of free inodes
    'I>',  'new_inode',          # new inode just allocated
    'I>',  'dir_inode',          # last directory inode chunk
    #
    # Hash table of inodes which have been unlinked but are
    # still being referenced.
    #
    'I>64', 'unlinked_hash',     # the hash
    'a16', 'uuid',               # Filesystem uuid
    'I>',  'crc',                # CRC of alloc group inode info sector
    'I>',  'pad32',              #
    'Q>',  'last_write_seq',     # last write sequence
    'I>',  'free_root',          # root of the free inode btree
    'I>',  'free_level',         # levels in free inode btree
  ])

  #
  # The third AG block contains the AG FreeList, an array
  # of block pointers to blocks owned by the allocation btree code.
  #
  AG_FREELIST = BinaryStruct.new([
    'I>',  'magic_num',          # magic number of the filesystem
    'I>',  'seq_no',             # sequence # starting from 0
    'a16', 'uuid',               # Filesystem uuid
    'Q>',  'last_write_seq',     # last write sequence
    'I>',  'crc',                # CRC of alloc group inode info sector
    'I>',  'bno',                # actually XFS_AGFL_SIZE
  ])
  AG_FL_STRUCT_SIZE = AG_FREELIST.size

  # ////////////////////////////////////////////////////////////////////////////
  # // Class.

  class AllocationGroup
    AG_FREESPACE_SIZE = 512
    AG_INODEINFO_SIZE = 512
    AG_FREELIST_SIZE  = 512

    XFS_AGF_MAGIC                          = 0x58414746
    XFS_AGI_MAGIC                          = 0x58414749
    XFS_AGFL_MAGIC                         = 0x5841464c

    # /////////////////////////////////////////////////////////////////////////
    # // initialize
    attr_reader :stream, :agf, :agi, :agfl, :allocation_group_block

    def initialize(stream, _agno, sb)
      raise "XFS::AllocationGroup.initialize: Nil stream" if stream.nil?
      #
      # The stream should be pointing at the Allocation Group to be built on the disk.
      #
      @stream = stream

      @agf                    = AG_FREESPACE.decode(@stream.read(AG_FREESPACE_SIZE))
      @stream.seek(AG_FREESPACE_SIZE, IO::SEEK_CUR)
      @agi                    = AG_INODEINFO.decode(@stream.read(AG_INODEINFO_SIZE))
      @stream.seek(AG_INODEINFO_SIZE, IO::SEEK_CUR)
      @agfl                   = AG_FREELIST.decode(@stream.read(AG_FREELIST_SIZE))
      @stream.seek(-(AG_FREESPACE_SIZE + AG_INODEINFO_SIZE + AG_FREELIST_SIZE))
      @allocation_group_block = MiqMemory.create_zero_buffer(sb['block_size'])
      @allocation_group_block = @stream.read(sb['block_size'])

      # Grab some quick facts & make sure there's nothing wrong. Tight qualification.
      if @agf['magic_num'] != XFS_AGF_MAGIC
        raise "XFS::AllocationGroup.initialize: Invalid AGF magic number=[#{@agf['magic_num']}]"
      elsif @agi['magic_num'] != XFS_AGI_MAGIC
        raise "XFS::AllocationGroup.initialize: Invalid AGI magic number=[#{@agi['magic_num']}]"
      elsif @agfl['magic_num'] != XFS_AGFL_MAGIC
        raise "XFS::AllocationGroup.initialize: Invalid AGFL magic number=[#{@agfl['magic_num']}]"
      end
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Class helpers & accessors.

    # Dump object.
    def dump
      out = "\#<#{self.class}:0x#{format('%08x', object_id)}>\n"
      out << "AGI Magic number        : #{@agf['magic_num']}\n"
      out << "Version number          : #{@agf['version_num']})\n"
      out << "Sequence Number         : #{@agf['seq_no']}\n"
      out << "Length                  : #{@agf['length']}\n"
      out << "Root Blocks             : #{@agf['root_blocks']}\n"
      out << "Btree Levels            : #{@agf['btree_levels']}\n"
      out << "1st Freelist Blk Index  : #{@agf['fl_first']}\n"
      out << "Last Freelist Blk Index : #{@agf['fl_last']}\n"
      out << "# Blocks in Freelist    : #{@agf['fl_count']}\n"
      out << "# of Free Blocks        : #{@agf['free_blocks']}\n"
      out << "Longest Free Space      : #{@agf['longest']}\n"
      out << "# Blks in AG Free Btree : #{@agf['btree_blocks']}\n"
      out << "Filesystem UUID         : #{@agf['uuid']}\n"
      out << "Allocated Inodes        : #{@agi['count']}\n"
      out << "Root of Inode BTree     : #{@agi['root']}\n"
      out << "Levels in Inode BTree   : #{@agi['level']}\n"
      out << "Number of Free Inodes   : #{@agi['free_count']}\n"
      out << "Newest Inode Allocated  : #{@agi['new_inode']}\n"
      out << "Last Dir Inode Chunk    : #{@agi['dir_inode']}\n"
      out << "Root of Free Ino Btree  : #{@agi['free_root']}\n"
      out << "Levels in Free Ino Btree : #{@agi['free_level']}\n"
      out
    end
  end # class AllocationGroup
end # module XFS
