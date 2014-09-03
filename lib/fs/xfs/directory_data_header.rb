require 'directory'

module XFS
  #
  # xfs_dir2_data_hdr consists of the magic number
  # followed by 3 copies of the xfs_dir2_data_free structure
  #
  DIR_DATA_HEADER = BinaryStruct.new([
    'I>', 'magic',               # magic number
  ])
  SIZEOF_DIR_DATA_HEADER = DIR_DATA_HEADER.size

  DIR_DATA_FREE = BinaryStruct.new([
    'S>',  'offset',              # start of freespace
    'S>',  'length',              # length of freespace
  ])
  SIZEOF_DIR_DATA_FREE        = DIR_DATA_FREE.size
  XFS_DIR2_DATA_FD_COUNT      = 3
  SIZEOF_FULL_DIR_DATA_HEADER = SIZEOF_DIR_DATA_HEADER + SIZEOF_DIR_DATA_FREE * XFS_DIR2_DATA_FD_COUNT

  XFS_DIR2_BLOCK_MAGIC = 0x58443242 # XD2B: single block dirs
  XFS_DIR2_DATA_MAGIC  = 0x58443244 # XD2D: multiblock dirs

  class DirDataHeader
    attr_reader :data_header, :header_end

    def initialize(data)
      @data_header = DIR_DATA_HEADER.decode(data)
      if @data_header['magic'] != XFS_DIR2_BLOCK_MAGIC && @data_header['magic'] != XFS_DIR2_DATA_MAGIC
        raise "XFS::DirDataHeader: Invalid Magic Number #{@data_header['magic']}"
      end
      free_offset   = SIZEOF_DIR_DATA_HEADER
      @data_free    = []
      @free_end     = 0
      (1..XFS_DIR2_DATA_FD_COUNT).each do | i |
        @free_end     = SIZEOF_DIR_DATA_HEADER + SIZEOF_DIR_DATA_FREE * i
        @data_free[i] = DIR_DATA_FREE.decode(data[free_offset..@free_end])
        free_offset   = @free_end
      end
      @header_end = @free_end
    end
  end # class DirDataHeader
end   # module XFS
