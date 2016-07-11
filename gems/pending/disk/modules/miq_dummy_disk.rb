require 'memory_buffer'
require_relative "../MiqDisk"
require 'ostruct'

module MiqDummyDisk
  DEF_BLOCK_SIZE = 512
  DEF_DISK_SIZE  = 1024

  attr_reader :d_size, :blockSize, :dInfo

  def self.new(d_info = nil)
    @dInfo          = d_info || OpenStruct.new
    @dInfo.fileName = "dummy disk"
    @dInfo.d_size     ||= DEF_DISK_SIZE
    @dInfo.block_size ||= DEF_BLOCK_SIZE
    MiqDisk.new(self, @dInfo, 0)
  end

  def d_init
    @blockSize = @dInfo.block_size
    @diskType  = "dummy-disk"
  end

  def d_size
    @d_size ||= @dInfo.d_size
  end

  def d_write(_pos, _buf, len)
    len
  end

  def d_read(pos, len)
    return nil if pos >= @endByteAddr
    len = @endByteAddr - pos if (pos + len) > @endByteAddr
    buffer = MemoryBuffer.create(len)
    buffer
  end

  def d_close
  end
end
