$:.push("#{File.dirname(__FILE__)}/../../util")
require 'MiqMemory'


module Iso9660
	
	class FileData
		
		attr_reader :pos
		
		# Initialization
		def initialize(dirEntry, bootSector)
			raise "Nil directory entry" if dirEntry == nil
			raise "Nil boot sector" if bootSector == nil
			
			@bs = bootSector
			@de = dirEntry
			@last_sect = @de.fileSize.divmod(@bs.sectorSize)
			@last_sect[0] += 1 if @last_sect[1] > 0
			@last_sect = @last_sect[0]
			rewind
		end
		
		def rewind
			@pos = 0
		end
		
		def seek(offset, method = IO::SEEK_SET)
			@pos = case method
			when IO::SEEK_SET then offset
			when IO::SEEK_CUR then @pos + offset
			when IO::SEEK_END then @de.length - offset
			end
			@pos = 0 if @pos < 0
			@pos = @de.fileSize if @pos > @de.fileSize
			return @pos
		end
		
		def read(bytes = @de.fileSize)
			return nil if @pos >= @de.fileSize
			bytes = @de.fileSize - @pos if @pos + bytes > @de.fileSize
			
			# Get start & end locs.
			ss = @bs.sectorSize
			startSector, startOffset = @pos.divmod(ss)
			endSector, endOffset = (@pos + (bytes - 1)).divmod(ss)
			
			# Single sector.
			if startSector == endSector
				@pos += (endOffset - startOffset)
				return getSector(startSector)[startOffset..endOffset]
			end
			
			# Span sectors.
			out = MiqMemory.create_zero_buffer(bytes)
			totalLen = 0
			(startSector..endSector).each do |sect|
				offset = 0; len = ss
				if sect == startSector
					offset = startOffset
					len -= offset
				end
				len -= (ss - (endOffset + 1)) if sect == endSector
				out[totalLen, len] = getSector(sect)[offset, len]
				totalLen += len
				@pos += len
			end
			return out[0..totalLen]
		end
		
		def getSector(vsn)
			lsn = getLSN(vsn)
			raise "No logical sector for virtual sector #{vsn}." if lsn == -1
			@bs.getSectors(lsn, 1)
		end
		
		def getLSN(vsn)
			return -1 if vsn > @last_sect
			@de.fileStart + vsn
		end
		
	end
end # module Iso9660
