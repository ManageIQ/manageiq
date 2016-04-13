module Lvm2Thin
  class DataSpaceMap
    attr_accessor :struct

    def initialize(superblock, struct)
      @superblock = superblock
      @struct = struct
    end

    def btree_root_address
      @btree_root_address ||= @superblock.md_block_address(struct['bitmap_root'])
    end

    def btree
      @btree ||= BTree.new @superblock, btree_root_address, INDEX_ENTRY
    end
  end

  class MetadataSpaceMap
    def metadata_root_address
      @metadata_root_address ||= @superblock.md_block_address(struct['bitmap_root'])
    end

    def root
      @metadata_root ||= begin
        @superblock.seek metadata_root_address
        @superblock.read_struct METADATA_INDEX
      end
    end

    def indices
      @metadata_indices ||= (struct['nr_blocks'].to_f / @superblock.entries_per_block).ceil
    end

    def index_entries
      @index_entries ||=
        0.upto(indices-1).collect do |i|
          address = metadata_root_address + METADATA_INDEX.size + i * INDEX_ENTRY.size
          @superblock.seek address
          @superblock.read_struct INDEX_ENTRY
        end
    end

    def bitmaps
      @bitmaps ||= index_entries.collect do |index_entry|
        @superblock.seek @superblock.md_block_address(index_entry['blocknr'])
        @superblock.read_struct BITMAP_HEADER
      end
    end

    attr_accessor :struct

    def initialize(superblock, struct)
      @superblock = superblock
      @struct     = struct
    end
  end
end # module Lvm2Thin
