require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. util})))
require 'MiqMemory'

describe MiqMemory do
  MIQ_MEMORY_SIZES = [
    1,
    MiqMemory::PACK_MIN - 1,
    MiqMemory::PACK_MIN,
    1024,
    1048576,
    MiqMemory::PACK_MAX,
    MiqMemory::PACK_MAX + 1,
    1073741824,
  ]

  MIQ_MEMORY_SIZES.each do |bytes|
    it ".create_zero_buffer(#{bytes})" do
      buf = MiqMemory.create_zero_buffer(bytes)
      buf.length.should == bytes
			buf[0, 1].should  == "\0"
			buf[-1, 1].should == "\0"
      
      # GC call required, otherwise the * operator in
      # MiqMemory automatically fails on higher sizes
      buf = nil
      GC.start
    end
  end

  it('.create_quad_buf')  { MiqMemory.create_quad_buf.should  == [0].pack("Q") }
  it('.create_long_buf')  { MiqMemory.create_long_buf.should  == [0].pack("L") }
  it('.create_short_buf') { MiqMemory.create_short_buf.should == [0].pack("S") }
end
