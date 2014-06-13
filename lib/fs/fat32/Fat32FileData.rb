require 'Fat32BootSect'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'MiqMemory'

module Fat32

	class FileData
		
		attr_reader :pos
		
		# Initialization
		def initialize(dirEntry, bootSector)
			raise "Nil directory entry" if dirEntry == nil
			raise "Nil boot sector" if bootSector == nil
			
			@bs = bootSector
			@de = dirEntry
			rewind
		end
		
		def rewind
			@pos = 0
		end
		
		def firstCluster
			return -1 if not @clusterMap or @clusterMap.size == 0
			return @clusterMap[0]
		end
		
		def seek(offset, method = IO::SEEK_SET)
			@pos = case method
				when IO::SEEK_SET then offset
				when IO::SEEK_CUR then @pos + offset
				when IO::SEEK_END then @de.length - offset
			end
			@pos = 0 if @pos < 0
			@pos = @de.length if @pos > @de.length
			return @pos
		end
		
		def read(bytes = @de.length)
			return nil if @pos >= @de.length
			@clusterMap = @bs.mkClusterMap(@de.firstCluster) if not @clusterMap
			
			# Get start & end locs.
			bpc = @bs.bytesPerCluster
			startCluster, startOffset = @pos.divmod(bpc)
			endCluster, endOffset = (@pos + (bytes - 1)).divmod(bpc)
			
			# Single cluster.
			if startCluster == endCluster
				@pos += (endOffset - startOffset)
				return getCluster(startCluster)[startOffset..endOffset]
			end
			
			# Span clusters.
			out = MiqMemory.create_zero_buffer(bytes)
			totalLen = 0
			(startCluster..endCluster).each do |clus|
				offset = 0; len = bpc
				if clus == startCluster
					offset = startOffset
					len -= offset
				end
				len -= (bpc - (endOffset + 1)) if clus == endCluster
				out[totalLen, len] = getCluster(clus)[offset, len]
				totalLen += len
				@pos += len
			end
			return out[0..totalLen]
		end
		
		def write(buf, bytes = buf.length)
			@clusterMap = @bs.mkClusterMap(@de.firstCluster) if not @clusterMap
			
			# Get start & end locs.
			bytesWritten = 0; bpc = @bs.bytesPerCluster
			startCluster, startOffset = @pos.divmod(bpc)
			endCluster, endOffset = (@pos + (bytes - 1)).divmod(bpc)
			
			# For each cluster, read, deposit & write.
			(startCluster..endCluster).each do |clus|
				offset = 0; len = bpc
				if clus == startCluster
					offset = startOffset
					len -= offset
				end
				len -= (bpc - (endOffset + 1)) if clus == endCluster
				current = getCluster(clus)
				current[startOffset, len] = buf[bytesWritten, len]
				putCluster(clus, current)
				@pos += len; bytesWritten += len
			end
			@de.length = @pos if @pos > @de.length
			@de.firstCluster = @clusterMap[0] if @de.firstCluster == 0
			return bytesWritten
		end
		
		def getCluster(vcn)
			lcn = getLCN(vcn)
			#puts "vcn=#{vcn}, lcn=#{lcn}" if $track_pos
			return MiqMemory.create_zero_buffer(@bs.bytesPerCluster) if lcn == -1
			raise "LCN is nill" if lcn.nil?
			@bs.getCluster(lcn)
		end
		
		def putCluster(vcn, buf)
			lcn = getLCN(vcn)
			if lcn == -1
				lcn = @bs.allocClusters(@clusterMap.size == 0 ? 0 : @clusterMap[@clusterMap.size - 1])
				@clusterMap << lcn
			end
			@bs.writeClusters(lcn, buf)
		end
		
		def close
			@de.close(@bs)
		end
		
		def getLCN(relClus)
			return -1 if relClus >= @clusterMap.size or @clusterMap.size == 0
			lcn = @clusterMap[relClus]
			if lcn.nil?
				#puts "LCN is nil for VCN #{relClus}; Map size is #{@clusterMap.size}, cluster map follows:"
				#puts @clusterMap.inspect
				raise "Bad cluster map."
			end
			return lcn
		end
		
	end
end # module Fat32
