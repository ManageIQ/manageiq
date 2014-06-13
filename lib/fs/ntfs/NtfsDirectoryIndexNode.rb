$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'

require 'NtfsAttribFileName'

module NTFS

	DIR_INDEX_NODE = BinaryStruct.new([
		'Q',  'mft_ref',          # MFT file reference for file name (goofy ref).
		'S',  'length',           # Length of entry.
		'S',  'content_len',      # Length of $FILE_NAME attrib
		'L',  'flags',            # See IN_ below (note: these will eventually become general flags)
	])
	# Here follows a $FILE_NAME attribute if content_len > 0.
	# Last 8 bytes starting on 8 byte boundary are the VCN of the child node in $INDEX_ALLOCATION (if IN_HAS_CHILD is set).
  SIZEOF_DIR_INDEX_NODE = DIR_INDEX_NODE.size

	class DirectoryIndexNode
	  
		IN_HAS_CHILD   = 0x00000001
		IN_LAST_ENTRY  = 0x00000002
	  
		attr_reader :refMft, :length, :contentLen, :flags, :child, :afn, :mftEntry
	  
	  def self.nodeFactory(buf)
			nodes = Array.new
			loop do
			  node   = DirectoryIndexNode.new(buf)
			  buf    = buf[node.length..-1]
			  nodes << node
        break if node.isLast?
		  end
		  
			return nodes
	  end
	  
		def initialize(buf)
			raise "MIQ(NTFS::DirectoryIndexNode.initialize) Nil buffer" if buf.nil?
	    buf = buf.read(buf.length) if buf.kind_of?(DataRun)
			# Decode the directory index node structure.
			@din = DIR_INDEX_NODE.decode(buf)
	    
			# Get accessor data.
			@mftEntry   = nil
			@refMft     = NtUtil.MkRef(@din['mft_ref'])
			@length     = @din['length']
			@contentLen = @din['content_len']
			@flags      = @din['flags']
	    
			# If there's a $FILE_NAME attrib get it.
			@afn = FileName.new(buf[SIZEOF_DIR_INDEX_NODE, buf.size]) if @contentLen > 0

			# If there's a child node VCN get it.
			if NtUtil.gotBit?(@flags, IN_HAS_CHILD)
				# Child node VCN is located 8 bytes before 'length' bytes.
				# NOTE: If the node has 0 contents, it's offset 16.
        @child = buf[@contentLen == 0 ? 16 : @length - 8, 8].unpack('Q')[0]
				if @child.class == Bignum
					#buf.hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
					raise "MIQ(NTFS::DirectoryIndexNode.initialize) Bad child node: #{@child}"
				end
			end
		end
		
		# String rep.
		def to_s
      "\#<#{self.class}:0x#{'%08x' % self.object_id} name='#{self.name}'>"
		end
	  
		# Return file name (if resolved).
		def name
			@afn.nil? ? nil : @afn.name
		end
	  
		# Return namespace.
		def namespace
		  @afn.nil? ? nil : @afn.namespace
		end
	  
		# Return true if has children.
		def hasChild?
			NtUtil.gotBit?(@flags, IN_HAS_CHILD)
		end
	  
		# Return true if this is the last entry.
		def isLast?
			NtUtil.gotBit?(@flags, IN_LAST_ENTRY)
		end
  
		# If content is 0, then obviously not a directory.
		def isDir?
			return false if @contentLen == 0
			return @mftEntry.isDir?
		end
	  
		# Resolves this node's file reference.
		def resolve(bs)
			if @contentLen > 0
				@mftEntry = bs.mftEntry(@refMft[1])
				raise "MIQ(NTFS::DirectoryIndexNode.resolve) Stale reference: #{self.inspect}" if @refMft[0] != @mftEntry.sequenceNum
			end
			return @mftEntry
		end
	    
		# Dumps object.
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Mft Ref : seq #{@refMft[0]}, entry #{@refMft[1]}\n"
			out << "  Length  : #{@length}\n"
			out << "  Content : #{@contentLen}\n"
			out << "  Flags   : 0x#{'%08x' % @flags}\n"
			out << @afn.dump if @contentLen > 0
			out << "  Child ref: #{@child}\n" if NtUtil.gotBit?(@flags, IN_HAS_CHILD)
			out << "---\n"
		end
	end
end # module NTFS
