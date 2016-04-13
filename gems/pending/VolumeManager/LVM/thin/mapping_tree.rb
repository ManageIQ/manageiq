module Lvm2Thin
  class MappingTree < BTree
    def initialize(superblock, root_address)
      super superblock, root_address, MAPPING_DETAILS
    end

    def entries
      @mtentries ||= begin
        super.collect do |entry|
          DataMap.new @superblock, @superblock.md_block_address(entry['value'])
        end
      end
    end

    def map_for(device_id)
      entry_for(device_id)
    end
  end
end # module Lvm2Thin
