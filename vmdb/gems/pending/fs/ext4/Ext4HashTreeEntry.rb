$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext4

  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  HASH_TREE_ENTRY_FIRST = BinaryStruct.new([
    'S',  'max_descriptors',  # Maximum number of node descriptors.
    'S',  'cur_descriptors',  # Current number of node descriptors.
    'L',  'first_node',       # Block address of first node.
  ])
  SIZEOF_HASH_TREE_ENTRY_FIRST = HASH_TREE_ENTRY_FIRST.size

  HASH_TREE_ENTRY_NEXT = BinaryStruct.new([
    'L',  'min_hash',   # Minimum hash value in node.
    'L',  'next_node',  # Block address of next node.
  ])
  SIZEOF_HASH_TREE_ENTRY_NEXT = HASH_TREE_ENTRY_NEXT.size
  
  SIZEOF_HASH_TREE_ENTRY = SIZEOF_HASH_TREE_ENTRY_NEXT

  class HashTreeEntry

    attr_reader :first, :max_descriptors, :cur_descriptors, :node, :min_hash

    def initialize(buf, first = false)
      raise "Ext4::HashTreeEntry.initialize: Nil buffer" if buf.nil?

      @first = first

      if first
        @hte             = HASH_TREE_ENTRY_FIRST.decode(buf)
        @max_descriptors = @hte['max_descriptors']
        @cur_descriptors = @hte['cur_descriptors']
        @node            = @hte['first_node']
      else
        @hte             = HASH_TREE_ENTRY_NEXT.decode(buf)
        @min_hash        = @hte['min_hash']
        @node            = @hte['next_node']
      end
    end

    def dump
      out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
      if @first
        out += "First Node?     : true\n"
        out += "Max Descriptors : #{@max_descriptors}\n"
        out += "Cur Descriptors : #{@cur_descriptors}\n"
        out += "First Node      : #{@node}\n"
      else
        out += "First Node?     : false\n"
        out += "Min Hash        : #{@min_hash}\n"
        out += "Next Node       : #{@node}\n"
      end

      out
    end

  end
end
