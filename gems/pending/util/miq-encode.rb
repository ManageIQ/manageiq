require 'zlib'
require 'uri'

class MIQEncode
  @@base64Pattern = Regexp.new("[^#{URI::PATTERN::UNRESERVED}]")

  def self.encode(data, compress=true)
	  return [Zlib::Deflate.deflate(data)].pack("m") if compress
	  return [data].pack("m")
  end
  
  def self.decode(data, compressed=true)
	  return Zlib::Inflate.inflate(data.unpack("m")[0]) if compressed
	  return data.unpack("m")[0]
  end

  def self.base64Encode(data)
    URI.encode(data, @@base64Pattern)
  end

  def self.base64Decode(data)
    URI.decode(data)
  end
	
	def self.base24Decode(byteArray)
		digits = %w[B C D F G H J K M P Q R T V W X Y 2 3 4 6 7 8 9]
		out = " " * 29
		out.length.downto(0) {|i|
			if i.modulo(6) == 0
				out[i, 1] = "-"
			else
				mapIndex = 0
				15.downto(0) {|j|
					byteValue = (mapIndex << 8) | byteArray[j]
					byteArray[j], mapIndex = byteValue.divmod(24)
					out[i, 1] = digits[mapIndex]
				}
			end
		}
		return out[1..-1]
	end
	
end