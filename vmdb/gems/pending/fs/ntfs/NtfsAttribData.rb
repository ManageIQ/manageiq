require 'NtUtil'

$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'

module NTFS
		
	class AttribData
	  
    # 
    # DATA_ATTR - Attribute: Data attribute (0x80)
    # 
    # NOTE: Can be resident or non-resident.
    # 
    # Data contents of a file (i.e. the unnamed stream) or of a named stream.
    # 
	  
    def self.create_from_header(header, buf)
      return AttribData.new(buf) if header.namelen == 0
      $log.debug("MFT Alternate Data Stream (#{header.name})") if $log
      return nil
    end
    
		attr_reader :data, :length, :run
		
		def initialize(buf)
		  @run    = buf if buf.kind_of?(NTFS::DataRun)
		  @data   = buf 
			@length = @data.length
			@pos    = 0
		end
		
		def to_s
		  return @data.hex_dump if @data.kind_of?(String)
		  
	    raise "MIQ(NTFS::AttribData.to_s) Unexpected data class: #{@data.class}" unless @data.kind_of?(NTFS::DataRun)

		  # Must be a Data Run
		  savedPos = @pos
		  seek(0)
			data = read(@length)
			seek(savedPos)
			return data
		end
	  
		# This now behaves exactly like a normal read.
		def read(bytes = @length)
			return nil if @pos >= @length
			bytes = @length - @pos if bytes.nil?
			bytes = @length - @pos if @pos + bytes > @length

			out = @data[@pos, bytes]			if @data.kind_of?(String)
			out = @data.read(bytes)       if @data.kind_of?(NTFS::DataRun)
			
			@pos += out.size
			return out
		end
	  
		def seek(offset, method = IO::SEEK_SET)
			@pos = case method
				when IO::SEEK_CUR then (@pos    + offset)
				when IO::SEEK_END then (@length - offset)
				when IO::SEEK_SET then offset
			end
			@data.seek(offset, method) if @data.kind_of?(NTFS::DataRun)
			return @pos
		end

    def rewind
      self.seek(0)
    end
	  
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Length: #{@length}\n"
			out << @data.dumpRunList if @data.class == NTFS::DataRun
			out << "---\n"
		end

	end
end # module NTFS
