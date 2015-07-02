$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'

module NTFS

  # 
  # INDEX_HEADER
  # 
  # This is the header for indexes, describing the INDEX_ENTRY records, which
  # follow the INDEX_HEADER. Together the index header and the index entries
  # make up a complete index.
  # 
  # IMPORTANT NOTE: The offset, length and size structure members are counted
  # relative to the start of the index header structure and not relative to the
  # start of the index root or index allocation structures themselves.
  # 
		
	INDEX_NODE_HEADER = BinaryStruct.new([
		'L',  'entries_offset',     # Byte offset from the INDEX_HEADER to first INDEX_ENTRY, aligned to 8-byte boundary
		'L',  'index_length',       # Data size in byte of the INDEX_ENTRY's, including the INDEX_HEADER, aligned to 8.
		'L',  'allocated_size',     # Offset to end of allocated index entry list buffer (relative to start of node header).
		
		# 
  	# For the index root attribute, the above two numbers are always
  	# equal, as the attribute is resident and it is resized as needed.
    # 
  	# For the index allocation attribute, the attribute is not resident 
  	# and the allocated_size is equal to the index_block_size specified 
  	# by the corresponding INDEX_ROOT attribute minus the INDEX_BLOCK 
  	# size not counting the INDEX_HEADER part (i.e. minus -24).
  	# 
  	
		'L',  'flags',              # See NH_ below.
	])
	SIZEOF_INDEX_NODE_HEADER = INDEX_NODE_HEADER.size
	# Here follows a list of IndexNodeEntries.
	
	class IndexNodeHeader
	  
		NH_HAS_CHILDREN = 0x0001
	  
		attr_reader :startEntries, :endEntries, :flags
	  
		def initialize(buf)
			raise "MIQ(NTFS::IndexNodeHeader.initialize) Nil buffer" if buf.nil?
			buf  = buf.read(buf.length) if buf.kind_of?(DataRun)
			@inh = INDEX_NODE_HEADER.decode(buf)
	    
			# Get accessor data.
			@flags        = @inh['flags']
			@endEntries   = @inh['index_length']
			@startEntries = @inh['entries_offset']
		end
	  
		def to_s
			"0x#{'%08x' % @flags}"
		end
	  
		def hasChildren?
			(@flags & NH_HAS_CHILDREN) == NH_HAS_CHILDREN
		end
	  
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Entries Offset   : #{@startEntries}\n"
			out << "  Index Length     : #{@endEntries}\n"
			out << "  Allocated Size   : #{@inh['allocated_size']}\n"
			out << "  Flags            : 0x#{'%08x' % @flags}\n"
			out << "---\n"
		end
	end
end # module NTFS
