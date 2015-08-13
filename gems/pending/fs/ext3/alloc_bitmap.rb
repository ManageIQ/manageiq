module Ext3
	
	class AllocBitmap
		
		def initialize(data)
			raise "Ext3::AllocBitmap.initialize: Nil data" if data.nil?
			@data = data
		end
		
		def isAllocated?(number)
			return getStatus(number)
		end
		
		def [](number)
			return getStatus(number)
		end
		
		def dump
			return @data.hex_dump
		end

		private
		
		def getStatus(number)
			byte, mask = index(number)
			return @data[byte] & mask == mask
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
		
	end #class
end #module
