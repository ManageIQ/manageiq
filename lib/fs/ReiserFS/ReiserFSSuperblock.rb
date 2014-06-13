$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'stringio'

require 'ReiserFSBlock'
require 'ReiserFSUtils'

require 'rufus/lru'

module ReiserFS
  
  SUPERBLOCK = BinaryStruct.new([
		'V',	'num_blocks',					# The number of blocks in the partition
		'V',  'num_free_blocks',    # The number of free blocks in the partition
		'V',  'root_block',         # The block number of the block containing the root node
		'V',  'journal_block',      # The block number of the block containing the first journal node
		'V',  'journal_device',     # Journal device number
		'V',  'journal_original_size',  # Original journal size
		'V',  'journal_trans_max',  # The maximum number of blocks in a transaction		
		'V',  'journal_magic',      # Journal magic number
		'V',  'journal_max_batch',  # The maximum number of blocks in a transaction		
		'V',  'journal_max_commit_age',  # Time in seconds of how old an asynchronous commit can be
		'V',  'journal_max_trans_age',   # Time in seconds of how old a transaction can be
		'v',	'block_size',					# Block size
		'v',  'oid_max_size',       # The maximum size of the object id array
		'v',  'oid_current_size',   # The current size of the object id array
		'v',  'state',              # State of the partition: valid (1) or error (2)
		'a12','magic',              # Magic String
		'V',  'hash_code',          # The hash function that is being used to sort names in a directory
		'v',	'tree_height',				# The current height of the disk tree
		'v',	'bitmap_number',			# The amount of bitmap blocks needed to address each block of the file system
		'v',	'version',  					# The reiserfs version number
		'a2',	'reserved',  					# 
		'V',  'inode_generation',   # Number of the current inode generation
	])
	SUPERBLOCK_SIZE   = SUPERBLOCK.size
	SUPERBLOCK_OFFSET = 64 * 1024
	
  class Superblock
    # Default cache sizes.
    DEF_LEAF_NODE_CACHE_SIZE = 50

    attr_reader :rootBlock, :blockSize, :treeHeight, :bitmapNumber, :nblocksInBitmap
    
    def initialize(stream)
			raise "Nil stream" if stream.nil?
			@stream = stream
			
			# Seek, read & decode the superblock structure
			@stream.seek(SUPERBLOCK_OFFSET)
			@sb = SUPERBLOCK.decode(@stream.read(SUPERBLOCK_SIZE))

			# Grab some quick facts & make sure there's nothing wrong. Tight qualification.
			raise "Invalid Magic String: #{@sb['magic']}" if not isMagic?(@sb['magic'])

      @totalBlocks  = @sb['num_blocks']
      @freeBlocks   = @sb['num_free_blocks']
			@rootBlock    = @sb['root_block']
			@treeHeight   = @sb['tree_height']
			@bitmapNumber = @sb['bitmap_number']
			@version      = @sb['version']
			@state        = @sb['state']
      @blockSize    = @sb['block_size']
			@nblocksInBitmap = 8 * @blockSize
			@oidMaxSize     = @sb['oid_max_size']
			@oidCurrentSize = @sb['oid_current_size']
			@superBlock   = SUPERBLOCK_OFFSET / @blockSize

      @leaf_nodes   = LruHash.new(DEF_LEAF_NODE_CACHE_SIZE)
		end
		
		def getBitmapBlock(bitmapNum)
		  if bitmapNum == 0
		    blockNum = @superBlock+1
	    else
	      blockNum = bitmapNum * @nblocksInBitmap
      end
      
		  readBlockRaw(blockNum)
	  end
		
		def blockUsed?(blockNum)
		  bitmapNum = blockNum / @nblocksInBitmap
		  raise "Block out of Range" if bitmapNum >= @bitmapNumber
		  
		  bitmapBlock      = getBitmapBlock(bitmapNum)
		  bitmapOffset     = blockNum % @nblocksInBitmap
		  bitmapByte       = bitmapOffset / 8
		  bitmapByteOffset = bitmapOffset % 8
		  bits = bitmapBlock[bitmapByte,1].unpack('B8')[0]
		  
		  return (bits[bitmapByteOffset,1] == "1")
	  end
		
		def readBlockRaw(blockNum)
			raise "ReiserFS::SuperBlock >> blockNum is nil" if blockNum.nil?
			
			@stream.seek(blockNum*@blockSize)
			@stream.read(@blockSize)
		end

		def readBlock(blockNum)
#		  return nil if !blockUsed?(blockNum)
			data = readBlockRaw(blockNum)
			Block.new(data, blockNum)
		end
		
		def getLeafNodes(key)
      key_s = Utils.dumpKey(key)
      return @leaf_nodes[key_s] if @leaf_nodes.has_key?(key_s)

      blocks = Array.new
      leaves = Array.new
      blocks << readBlock(@rootBlock)
      blocks.each do |block|
        next if block.nil?
        
        if block.isLeaf?
          leaves << block   
          next
        end
        
        block.findPointers(key).each do |pointer|
          blocks << readBlock(pointer['block_number'])
        end
      end
      
      return @leaf_nodes[key_s] = leaves
	  end

		# Returns free space on file system in bytes.
  	def freeBytes
  	  @freeBlocks * @blockSize
	  end
	  
		private
		
  	def isMagic?(magic)
      return ["ReIsErFs", "ReIsEr2Fs", "ReIsEr3Fs"].include?(magic.strip)
    end
  	
		
	end
  
end
