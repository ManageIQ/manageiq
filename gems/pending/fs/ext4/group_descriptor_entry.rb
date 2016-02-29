require 'binary_struct'

module Ext4
  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  GDE = BinaryStruct.new([
    'L',  'blk_bmp',        # Starting block address of block bitmap.
    'L',  'inode_bmp',      # Starting block address of inode bitmap.
    'L',  'inode_table',    # Starting block address of inode table.
    'S',  'unalloc_blks',   # Number of unallocated blocks in group.
    'S',  'unalloc_inodes', # Number of unallocated inodes in group.
    'S',  'num_dirs',       # Number of directories in group.
    'a14',  'unused1',      # Unused.
  ])

  #SIZEOF_GDE = GDE.size
  # if sb.isEnabled64Bit?, the size of GDE will be 64 with extra information. 
  # Because the current GDE structure has all the information we need, we'll
  # continue to use it unless we have to expand it to 64.

  # ////////////////////////////////////////////////////////////////////////////
  # // Class.

  class GroupDescriptorEntry
    attr_accessor :blockAllocBmp, :inodeAllocBmp

    def initialize(buf)
      raise "Ext4::GroupDescriptorEntry.initialize: Nil buffer" if buf.nil?

      # Decode the group descriptor table entry.
      @gde = GDE.decode(buf)
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Class helpers & accessors.

    def blockBmp
      @gde['blk_bmp']
    end

    def inodeBmp
      @gde['inode_bmp']
    end

    def inodeTable
      @gde['inode_table']
    end

    def numDirs
      @gde['num_dirs']
    end

    # ////////////////////////////////////////////////////////////////////////////
    # // Utility functions.

    # Dump object.
    def dump
      out = "\#<#{self.class}:0x#{'%08x' % object_id}>\n"
      out += "Block bitmap      : 0x#{'%08x' % @gde['blk_bmp']}\n"
      out += "Inode bitmap      : 0x#{'%08x' % @gde['inode_bmp']}\n"
      out += "Inode table       : 0x#{'%08x' % @gde['inode_table']}\n"
      out += "Unallocated blocks: 0x#{'%04x' % @gde['unalloc_blks']}\n"
      out += "Unallocated inodes: 0x#{'%04x' % @gde['unalloc_inodes']}\n"
      out += "Num directories   : 0x#{'%04x' % @gde['num_dirs']}\n"
      out
    end
  end
end
