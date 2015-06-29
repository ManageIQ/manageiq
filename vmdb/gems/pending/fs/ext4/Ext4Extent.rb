$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'

module Ext4

  # ////////////////////////////////////////////////////////////////////////////
  # // Data definitions.

  EXTENT = BinaryStruct.new([
    'L',  'block',      # first logical block extent covers
    'S',  'length',     # number of blocks covered by extent
    'S',  'start_hi',   # high 16 bits of physical block
    'L',  'start_lo',   # low  32 bits of physical block
  ])
  SIZEOF_EXTENT = EXTENT.size

  class Extent

    attr_reader :block, :length, :start

    def initialize(buf)
      raise "Ext4::Extent.initialize: Nil buffer" if buf.nil?
      @extent = EXTENT.decode(buf)

      @block      = @extent['block']
      @length     = @extent['length']
      @start      = (@extent['start_hi'] << 32) | @extent['start_lo']
    end

    def dump
      out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
      out += "Block        : #{@block}\n"
      out += "Length       : #{@length}\n"
      out += "Start        : #{@start}\n"
      out
    end
  end
end
