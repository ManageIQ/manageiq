module XFS
  #
  # xfs_dir2_data_hdr consists of the magic number
  # followed by 3 copies of the xfs_dir2_data_free structure
  #
  DIRECTORY_BLOCK_TAIL = BinaryStruct.new([
    'I>', 'count',               # total number of leaf entries
    'I>', 'stale',               # total number of free entries
  ])
  SIZEOF_DIRECTORY_BLOCK_TAIL = DIRECTORY_BLOCK_TAIL.size

  class DirectoryBlockTail
    attr_reader :count, :stale, :size

    def initialize(data)
      tail = DIRECTORY_BLOCK_TAIL.decode(data)
      @count = tail['count']
      @stale = tail['stale']
      @size  = SIZEOF_DIRECTORY_BLOCK_TAIL
    end
  end # class DirectoryBlockTail
end   # module XFS
