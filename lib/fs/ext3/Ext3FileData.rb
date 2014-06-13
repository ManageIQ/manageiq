$:.push("#{File.dirname(__FILE__)}/../../util")
require 'MiqMemory'

require 'Ext3BlockPointersPath'

module Ext3

	class FileData
    
		SIZEOF_LONG           = 4
		MAX_READ		          = 4294967296
		DEFAULT_BLOCK_SIZE    = 1024
		
		attr_reader :pos

		# Initialization
		def initialize(inodeObj, superblock)
			raise "Ext3::FileData.initialize: Nil inode object" if inodeObj.nil?
			raise "Ext3::FileData.initialize: Nil superblock"   if superblock.nil?
			
			@sb         = superblock
			@inodeObj   = inodeObj
			@blockSize  = @sb.blockSize
      @path = BlockPointersPath.new(@blockSize / SIZEOF_LONG)
  		
			rewind
		end
		
		def rewind
			@pos = 0
		end
		
		def seek(offset, method = IO::SEEK_SET)
			@pos = case method
				when IO::SEEK_SET then offset
				when IO::SEEK_CUR then @pos + offset
				when IO::SEEK_END then @inodeObj.length - offset
			end
			@pos = 0                if @pos < 0
			@pos = @inodeObj.length if @pos > @inodeObj.length
			return @pos
		end
			
		def read(bytes = @inodeObj.length)
			raise "Ext3::FileData.read: Can't read 4G or more at a time (use a smaller read size)" if bytes >= MAX_READ
			return nil if @pos >= @inodeObj.length
			
			# Handle symbolic links.
			if @inodeObj.symlnk
				out = @inodeObj.symlnk[@pos...bytes]
				@pos += bytes
				return out
			end
			bytes = @inodeObj.length - @pos if @pos + bytes > @inodeObj.length
			
			# get data.
			startBlock, startByte, endBlock, endByte, nblocks = getStartBlock(@pos, bytes)
			out = getBlocks(startBlock, nblocks)
			@pos += bytes
			return out[startByte, bytes]
		end
		
		def write(buf, len = buf.length)
			raise "Ext3::FileData.write: Write functionality is not yet supported on Ext3."
			@dirty = true
		end

		private
		
		def getStartBlock(pos, len)
			startBlock, startByte = pos.divmod(@blockSize)
			endBlock, endByte = (pos + len - 1).divmod(@blockSize)
			nblocks = endBlock - startBlock + 1
      return startBlock, startByte, endBlock, endByte, nblocks
		end
		
		def getBlocks(startBlock, nblocks = 1)
      @path.block = startBlock
			out = MiqMemory.create_zero_buffer(nblocks * @blockSize)
			nblocks.times do |i|
				out[i * @blockSize, @blockSize] = getBlock(@path)
				@path.succ!
			end
			return out
		end
		
		def getBlock(path)
      pointer = case path.index_type
      when :direct
        @inodeObj.blockPointers[path.direct_index]
      when :single_indirect
        p = getSingleIndirectPointers(@inodeObj.sngIndBlockPointer)
				p[path.single_indirect_index]
      when :double_indirect
        p = getDoubleIndirectPointers(@inodeObj.dblIndBlockPointer)
				p = getSingleIndirectPointers(p[path.single_indirect_index])
				p[path.double_indirect_index]
      when :triple_indirect
        p = getTripleIndirectPointers(@inodeObj.dblIndBlockPointer)
        p = getDoubleIndirectPointers(p[path.single_indirect_index])
				p = getSingleIndirectPointers(p[path.double_indirect_index])
				p[path.triple_indirect_index]
      end

      return @sb.getBlock(pointer)
	  end
	  
	  def getSingleIndirectPointers(block)
	    return @singleIndirectPointers if block == @singleIndirectBlock
	    @singleIndirectBlock    = block
	    @singleIndirectPointers = getBlockPointers(block)
    end

	  def getDoubleIndirectPointers(block)
	    return @doubleIndirectPointers if block == @doubleIndirectBlock
	    @doubleIndirectBlock    = block
	    @doubleIndirectPointers = getBlockPointers(block)
    end

	  def getTripleIndirectPointers(block)
	    return @tripleIndirectPointers if block == @tripleIndirectBlock
	    @tripleIndirectBlock    = block
	    @tripleIndirectPointers = getBlockPointers(block)
    end
	  
		def getBlockPointers(block)
			@sb.getBlock(block).unpack('L*')
		end	  
	end #class
end #module
