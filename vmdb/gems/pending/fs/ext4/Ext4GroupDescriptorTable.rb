require 'Ext4GroupDescriptorEntry'
require 'Ext4AllocBitmap'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext4

  class GroupDescriptorTable

    def initialize(sb)
      raise "Ext4::GroupDescriptorTable.initialize: Nil Superblock" if sb.nil?

      # Read all the group descriptor entries.
      @gdt = []
      sb.stream.seek(sb.blockToAddress(sb.blockSize == 1024 ? 2 : 1))
      buf = sb.stream.read(SIZEOF_GDE * sb.numGroups)
      offset = 0
      sb.numGroups.times do
        gde = GroupDescriptorEntry.new(buf[offset, SIZEOF_GDE])

        # Construct allocation bitmaps for blocks & inodes.
        gde.blockAllocBmp = getAllocBitmap(sb, gde.blockBmp, sb.blockSize)
        gde.inodeAllocBmp = getAllocBitmap(sb, gde.inodeBmp, sb.inodesPerGroup / 8)

        @gdt << gde
        offset += SIZEOF_GDE
      end
    end

    def each
      @gdt.each {|gde| yield(gde)}
    end

    def [] (group)
      return @gdt[group]
    end

    def dump(dump_bitmaps = false)
      out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
      @gdt.each do |gde|
        out += gde.dump
        if dump_bitmaps
          out += "Block allocation\n#{gde.blockAllocBmp.dump}"
          out += "Inode allocation\n#{gde.inodeAllocBmp.dump}"
        end
      end
      return out
    end

    private

    def getAllocBitmap(sb, block, size)
      sb.stream.seek(sb.blockToAddress(block))
      AllocBitmap.new(sb.stream.read(size))
    end

  end #class
end #module
