require 'directory'
require 'superblock'

module XFS
  #
  # xfs_dir2_data_hdr consists of the magic number
  # followed by 3 copies of the xfs_dir2_data_free structure
  #
  DIRECTORY2_DATA_HEADER = BinaryStruct.new([
    'I>', 'magic',               # magic number
  ])
  SIZEOF_DIRECTORY2_DATA_HEADER = DIRECTORY2_DATA_HEADER.size

  class Directory2DataHeader
    XFS_DIR2_BLOCK_MAGIC        = 0x58443242 # XD2B: single block dirs
    XFS_DIR2_DATA_MAGIC         = 0x58443244 # XD2D: multiblock dirs

    attr_reader :template, :magic_numbers, :pad, :version_3

    def initialize
      @template      = DIRECTORY2_DATA_HEADER
      @magic_numbers = [XFS_DIR2_BLOCK_MAGIC, XFS_DIR2_DATA_MAGIC]
      @pad           = 0
      @version_3     = false
    end
  end # class Directory3DataHeader
end   # module XFS
