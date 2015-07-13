$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext4

  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  EXTENT_INDEX = BinaryStruct.new([
    'L',  'block',      # index covers logical blocks from 'block'
    'L',  'leaf_lo',    # low  32 bits of physical block of the next level. leaf or next index could be there
    'S',  'leaf_hi',    # high 16 bits of physical block
    'S',  'unused',     #
  ])
  SIZEOF_EXTENT_INDEX = EXTENT_INDEX.size

  class ExtentIndex

    attr_reader :block, :leaf

    def initialize(buf)
      raise "Ext4::ExtentIndex.initialize: Nil buffer" if buf.nil?
      @ei = EXTENT_INDEX.decode(buf)

      @block      = @ei['block']
      @leaf       = (@ei['leaf_hi'] << 32) | @ei['leaf_lo']
    end

    def dump
      out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
      out += "Block        : #{@block}\n"
      out += "Leaf         : #{@leaf}\n"
      out
    end
  end
end
