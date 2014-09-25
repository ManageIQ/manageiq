$LOAD_PATH.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'miq-uuid'
require 'stringio'
require 'MiqMemory'

require 'rufus/lru'

module XFS
  # ////////////////////////////////////////////////////////////////////////////

  BTREE_BLOCK_SHORT_NOCRC = BinaryStruct.new([
    #  Common BTree Block header information
    'I>',  'magic_num',          # magic number of the btree block type
    'S>',  'level',              # level number.  0 is a leaf
    'S>',  'num_recs',           # current # of data records
    #
    #  Short Section
    #
    'I>',  'left_sibling',       #
    'I>',  'right_sibling',      #
  ])
  SIZEOF_BTREE_BLOCK_SHORT_NOCRC = BTREE_BLOCK_SHORT_NOCRC.size

  BTREE_BLOCK_SHORT = BinaryStruct.new([
    #  Common BTree Block header information
    'I>',  'magic_num',          # magic number of the btree block type
    'S>',  'level',              # level number.  0 is a leaf
    'S>',  'num_recs',           # current # of data records
    #
    #  Short Section
    #
    'I>',  'left_sibling',       #
    'I>',  'right_sibling',      #
    'Q>',  'block_num',          #
    'Q>',  'lsn',                #
    'a16', 'uuid',               #
    'I>',  'owner',              #
    'I>',  'crc',                #
  ])
  SIZEOF_BTREE_BLOCK_SHORT = BTREE_BLOCK_SHORT.size

  BTREE_BLOCK_LONG_NOCRC = BinaryStruct.new([
    #  Common BTree Block header information
    'I>',  'magic_num',          # magic number of the btree block type
    'S>',  'level',              # level number.  0 is a leaf
    'S>',  'num_recs',           # current # of data records
    #
    #  Long Section
    #
    'Q>',  'left_sibling',       #
    'Q>',  'right_sibling',      #
  ])
  SIZEOF_BTREE_BLOCK_LONG_NOCRC = BTREE_BLOCK_LONG_NOCRC.size

  BTREE_BLOCK_LONG = BinaryStruct.new([
    #  Common BTree Block header information
    'I>',  'magic_num',          # magic number of the btree block type
    'S>',  'level',              # level number.  0 is a leaf
    'S>',  'num_recs',           # current # of data records
    #
    #  Long Section
    #
    'Q>',  'left_sibling',       #
    'Q>',  'right_sibling',      #
    'Q>',  'block_num',          #
    'Q>',  'lsn',                #
    'a16', 'uuid',               #
    'Q>',  'owner',              #
    'I>',  'crc',                #
    'I>',  'pad',                #
  ])
  SIZEOF_BTREE_BLOCK_LONG = BTREE_BLOCK_LONG.size

  XFS_LOOKUP_EQ = 0
  XFS_LOOKUP_LE = 1
  XFS_LOOKUP_GE = 2

  XFS_BTNUM_BNO  = 0
  XFS_BTNUM_CNT  = 1
  XFS_BTNUM_BMAP = 2
  XFS_BTNUM_INO  = 3
  XFS_BTNUM_FINO = 4
  XFS_BTNUM_MAX  = 5

  # ////////////////////////////////////////////////////////////////////////////
  # // Class.

  class BmapBTreeBlock
    XFS_BTREE_LONG_PTRS = 1
    XFS_BMAP_MAGIC      = 0x424d4150
    # // initialize
    attr_reader :level, :number_records, :header_size, :buffer, :left_sibling, :right_sibling

    def initialize(buffer, sb)
      @sb = sb
      if defined? XFS_BTREE_LONG_PTRS
        if @sb.sb_version_hascrc
          @btree_block = BTREE_BLOCK_LONG.decode(buffer)
        else
          @btree_block = BTREE_BLOCK_LONG_NOCRC.decode(buffer)
        end
      else
        if sb.sb_version_hascrc
          @btree_block = BTREE_BLOCK_SHORT.decode(buffer)
        else
          @btree_block = BTREE_BLOCK_SHORT_NOCRC.decode(buffer)
        end
      end
      @header_size   = btree_block_length
      @number_records = @btree_block['num_recs']
      @level         = @btree_block['level']
      raise "Invalid BTreeBlock"       unless @btree_block['magic_num'] == XFS_BMAP_MAGIC
      @left_sibling  = @btree_block['left_sibling']
      @right_sibling = @btree_block['right_sibling']
      @buffer        = buffer
    end

    def btree_block_length
      if defined? XFS_BTREE_LONG_PTRS
        if @sb.sb_version_hascrc
          len = SIZEOF_BTREE_BLOCK_LONG
        else
          len = SIZEOF_BTREE_BLOCK_LONG_NOCRC
        end
      else
        if @sb.sb_version_hascrc
          len = SIZEOF_BTREE_BLOCK_SHORT
        else
          len = SIZEOF_BTREE_BLOCK_SHORT_NOCRC
        end
      end
      len
    end
  end # class BTreeBlock
end # module XFS
