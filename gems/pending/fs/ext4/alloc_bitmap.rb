module Ext4
  class AllocBitmap
    def initialize(data)
      raise "Ext4::AllocBitmap.initialize: Nil data" if data.nil?
      @data = data
    end

    def isAllocated?(number)
      getStatus(number)
    end

    def [](number)
      getStatus(number)
    end

    def dump
      @data.hex_dump
    end

    private

    def getStatus(number)
      byte, mask = index(number)
      @data[byte] & mask == mask
    end

    def index(number)
      byte, bit = number.divmod(8)
      if byte > @data.size - 1
        msg = "AllocBitmap#index: "
        msg += "byte index #{byte} is out of range for data[0:#{@data.size - 1}]"
        raise msg
      end
      mask = 128 >> bit
      return byte, mask
    end
  end # class
end # module
