$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext4

  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  HASH_TREE_HEADER = BinaryStruct.new([
    'L',  'unused1',    # Unused.
    'C',  'hash_ver',   # Hash version.
    'C',  'length',     # Length of this structure.
    'C',  'leaf_level', # Levels of leaves.
    'C',  'unused2',    # Unused.
  ])
  SIZEOF_HASH_TREE_HEADER = HASH_TREE_HEADER.size

  class HashTreeHeader

    attr_reader :hash_version, :length, :leaf_level

    def initialize(buf)
      raise "Ext4::HashTreeHeader.initialize: Nil buffer" if buf.nil?
      @hth = HASH_TREE_HEADER.decode(buf)

      @hash_version = @hth['hash_ver']
      @length       = @hth['length']
      @leaf_level   = @hth['leaf_level']
    end
    
    def dump
      out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
      out += "Hash Version : #{@hash_version}\n"
      out += "Length       : #{@length}\n"
      out += "Leaf Level   : #{@leaf_level}\n"
    end
  end
end
