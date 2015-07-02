require 'directory'
require 'superblock'

module XFS
  DIRECTORY3_DATA_HEADER = BinaryStruct.new([
    'I>',  'magic',               # magic number
    'I>',  'crc',                 # CRC of block
    'Q>',  'block_number',        # first block of the buffer
    'Q>',  'last_write_sequence', # sequence number of last write
    'a16', 'uuid',                # filesystem we belong to
    'Q>',  'owner',               # inode that owns the block
  ])
  SIZEOF_DIRECTORY3_DATA_HEADER = DIRECTORY3_DATA_HEADER.size

  DIRECTORY3_DATA_PAD = BinaryStruct.new([
    'I>',  'padding',             # padding
  ])
  SIZEOF_DIRECTORY3_DATA_PAD = DIRECTORY3_DATA_PAD.size

  class Directory3DataHeader
    XFS_DIR3_BLOCK_MAGIC        = 0x58444233 # XDB3: single block dirs
    XFS_DIR3_DATA_MAGIC         = 0x58444433 # XDD3: multiblock dirs

    attr_reader :template, :magic_numbers, :pad, :version_3

    def initialize
      @template      = DIRECTORY3_DATA_HEADER
      @magic_numbers = [XFS_DIR3_BLOCK_MAGIC, XFS_DIR3_DATA_MAGIC]
      @pad           = SIZEOF_DIRECTORY3_DATA_PAD
      @version_3     = true
      super
    end
  end # class Directory3DataHeader
end   # module XFS
