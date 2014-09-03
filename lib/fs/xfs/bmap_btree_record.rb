module XFS
  BMAP_BTREE_REC = BinaryStruct.new([
    'Q>',          'l0',
    'Q>',          'l1',
  ])

  SIZEOF_BMAP_BTREE_REC   = 16
  BMBT_EXNTFLAG_BITLEN    = 1
  BMBT_STARTOFF_BITLEN    = 54
  BMBT_STARTBLOCK_BITLEN  = 52
  BMBT_BLOCKCOUNT_BITLEN  = 21

  XFS_EXT_NORM            = 0
  XFS_EXT_UNWRITTEN       = 1
  XFS_EXT_DMAPI_OFFLINE   = 2
  XFS_EXT_INVALID         = 3

  class BmapBTreeRecord
    attr_accessor   :key_ptr, :start_offset, :start_block, :big_start_block, :block_count, :flag

    def xfs_mask64lo(shift)
      (1 << shift) - 1
    end

    def bmbt_get_state(doubleword)
      flag = doubleword >> (64 - BMBT_EXNTFLAG_BITLEN)
      return XFS_EXT_UNWRITTEN if flag > 0
      XFS_EXT_NORM
    end

    def bmbt_get_block_count(doubleword)
      doubleword & xfs_mask64lo(21)
    end

    def bmbt_get_start_offset(doubleword)
      (doubleword & xfs_mask64lo(64 - BMBT_EXNTFLAG_BITLEN)) >> 9
    end

    def bmbt_get_start_block(doubleword)
      doubleword  >> 21
    end

    def bmbt_get_big_start_block(word0, word1)
      ((word0 & xfs_mask64lo(9) << 43)) | (word1  >> 21)
    end

    def initialize(data)
      raise "XFS::BmapBTreeRec: Nil buffer" if data.nil?
      @record          = BMAP_BTREE_REC.decode(data)
      @start_offset    = bmbt_get_start_offset(@record['l0'])
      @start_block     = bmbt_get_start_block(@record['l1'])
      @big_start_block = bmbt_get_big_start_block(@record['l0'], @record['l1'])
      @block_count     = bmbt_get_block_count(@record['l1'])
      @flag            = bmbt_get_state(@record['l0'])
    end

    def set_record(cursor, level, key_number, block)
      super
      if level == 0
        record       = btree_rec_addr(cursor, key_number, block)
        @start_inode = record.start_inode
      end
      @key_pointer = btree_key_address(cursor, key_number, block)
    end

    def dump
      out = "\#<#{self.class}:0x#{format('%08x', object_id)}>\n"
      out += "Offset       : #{@start_offset}\n"
      out += "Start Block  : #{@start_block}\n"
      out += "Big Start Blk: #{@big_start_block}\n"
      out += "Block Count  : #{@block_count}\n"
      out += "Flag         : #{@flag}\n"
      out
    end
  end
end
