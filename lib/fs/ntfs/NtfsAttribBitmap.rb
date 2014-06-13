module NTFS
  class Bitmap
    # BITMAP_ATTR - Attribute: Bitmap (0xb0).
    # 
    # Contains an array of bits (aka a bitfield).
    # 
    # When used in conjunction with the index allocation attribute, each bit
    # corresponds to one index block within the index allocation attribute. Thus
    # the number of bits in the bitmap * index block size / cluster size is the
    # number of clusters in the index allocation attribute.
    # 

    def self.create_from_header(header, buf)
      return Bitmap.new(buf) if header.containsFileNameIndexes?
      $log.debug("Skipping #{header.typeName} for name <#{header.name}>") if $log
      return nil
    end
    
		attr_reader :data, :length

		def initialize(buf)
			@data   = buf.kind_of?(DataRun) ? buf.read(buf.length) : buf
			@length = @data.length
		end

  end
end
