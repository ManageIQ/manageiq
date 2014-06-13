require 'ReiserFSUtils'


module ReiserFS

	class FileData
		
		attr_reader :pos
		
		# Initialization
		def initialize(dirEntry, superblock)
			raise "Nil dirEntry object" if dirEntry.nil?
			raise "Nil superblock"      if superblock.nil?
			
			@sb   = superblock
			@de   = dirEntry
			@key  = @de.key
			@len  = @de.length
			@blocks = Array.new
			
#puts "Key=#{Utils.dumpKey(@key)} datalen=#{@len}"			

			@sb.getLeafNodes(@key).each do |leaf|
  			leaf.getItemHeaders(@key).each do |ih|
 			    next if Utils.typeIsStat?(leaf.getItemType(ih))
 			    raise "Directory Node when FileData expected" if Utils.typeIsDirectory?(leaf.getItemType(ih))

 			    if Utils.typeIsDirect?(leaf.getItemType(ih))
 			      @blocks << { :blockNum => leaf.blockNum, :offset => ih['location'], :length => ih['length'], :blockObj => leaf }
		      end

 			    if Utils.typeIsIndirect?(leaf.getItemType(ih))
 			      leaf.getItem(ih).unpack("V*").each do |blockNum|
   			      @blocks << { :blockNum => blockNum, :offset => 0, :length => @sb.blockSize }
            end
		      end
  			end
			end
			
	    @bpos  = Array.new
	    pos = 0
	    @blocks.each { |b|
	      @bpos << pos 
	      pos += b[:length]
	    }
	    
		  @blen  = @blocks[0][:length]
      
#      @blocks.each { |b| puts "Block(#{b['blockNum']}): len=#{b['length']} offset=#{b['offset']}"   }

			rewind
		end
		
		def findIndex(pos)
		  index = pos / @blen
		  index -= 1 while                    @bpos[index]   > pos
		  index += 1 while @bpos[index+1] && (@bpos[index+1] < pos)
		  index
	  end
		
		def rewind
			@pos = 0
		end
		
		def seek(offset, method = IO::SEEK_SET)
			@pos = case method
				when IO::SEEK_SET then offset
				when IO::SEEK_CUR then @pos + offset
				when IO::SEEK_END then @len - offset
			end
			@pos = 0    if @pos < 0
			@pos = @len if @pos > @len
			return @pos
		end
			
		def read(bytes = @len)
			return nil if @pos >= @len
			
			index = findIndex(@pos)
			out = ""

      while out.length < bytes
        b      = @blocks[index]
        pos    = @bpos[index]
        index += 1
        
			  blockLength = b[:length]
			  blockLength = (@len - pos) if (pos + blockLength) > @len

		    # Do we have to start reading from an offset?
        byteOffset = (pos < @pos) ? (@pos - pos) : 0
      
        # Get the block with data
        b[:blockObj] = @sb.readBlock(b[:blockNum])  unless b.has_key?(:blockObj)
        blockObj = b[:blockObj]
      
        # Extract the data we need out of it
			  blockOffset = b[:offset]
        out << blockObj.data[blockOffset+byteOffset, blockLength-byteOffset]
      end
      
      bytes = out.length if (bytes > out.length)
      @pos += bytes

			return out[0, bytes]
		end
		
		def write(buf, len = buf.length)
			raise "Write functionality is not yet supported on ReiserFS."
		end

		private
		

	end #class
end #module
