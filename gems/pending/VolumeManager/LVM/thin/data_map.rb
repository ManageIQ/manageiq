module Lvm2Thin
  class DataMap < BTree
    TIME_MASK = (1 << 24) - 1

    def initialize(superblock, root_address)
      super superblock, root_address, MAPPING_DETAILS
    end

    alias :device_blocks :keys

    def entries
      @dmentries ||= begin
        super.collect do |entry|
          value = entry['value']
          internal? ? DataMap.new(@superblock, @superblock.md_block_address(value)) :
                      [extract_data_block(value), extract_time(value)]
        end
      end
    end

    def data_block(device_block)
      device_blocks.reverse.each do |map_device_block|
        if map_device_block <= device_block
          entry = entry_for(map_device_block)
          return entry.data_block(device_block) if entry.is_a?(DataMap)
          raise RuntimeError, "LVM2Thin cannot find device block: #{device_block} (closest: #{map_device_block})" unless map_device_block == device_block
          return entry.first
        end
      end

      raise RuntimeError, "LVM2Thin could not find data block for #{device_block}"
    end

    private

    def extract_data_block(value)
      value >> 24
    end

    def extract_time(value)
      value & TIME_MASK
    end
  end
end # module Lvm2Thin
