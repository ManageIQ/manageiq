$:.push("#{File.dirname(__FILE__)}/../../../util")

require 'binary_struct'
require 'miq-unicode'

require 'NtfsAttribType'

module NTFS
		
	# Standard attribute header.
	# Each attribute begins with one of these.
	STANDARD_ATTRIBUTE_HEADER = BinaryStruct.new([
		'L',  'attrib_type',      # The (32-bit) type of the attribute
		'L',  'length',           # Byte size of the resident part of the attribute 
		                          # (aligned to 8-byte boundary).  Used to get to the next attribute
		'C',  'non_resident',     # If 0, attribute is resident.
                              # If 1, attribute is non-resident
		'C',  'name_length',      # Unicode character size of name of attribute.
                              # 0 if unnamed
		'S',  'name_offset',      # If name_length != 0, the byte offset to the beginning of the name 
		                          # from the attribute record. Note that the name is stored as a
                              # Unicode string.
		'S',  'flags',            # Attribute flags (see AF_ below)
		'S',  'attrib_id',        # The instance of this attribute record. This number is unique within this mft record
	])
	SIZEOF_STANDARD_ATTRIBUTE_HEADER = STANDARD_ATTRIBUTE_HEADER.size
	
	# The standard attribute header continues with one of the following two
	# structs depending on whether the attribute is resident or non-resident.
	
	# The resident struct.
	SAH_RESIDENT = BinaryStruct.new([
		'L',  'value_length',     # Byte size of attribute value
		'S',  'value_offset',     # Byte offset of the attribute value from the start of the attribute record
		'C',  'resident_flags',   # Flags of resident attributes (8-bit)
		'C',  nil,                # Reserved/alignment to 8-byte boundary
	])
	SIZEOF_SAH_RESIDENT = SAH_RESIDENT.size
	
	# The non-resident struct.
	SAH_NONRESIDENT = BinaryStruct.new([
		'Q',  'first_vcn',        # Lowest valid virtual cluster number	for this portion of the attribute value 
		                          # or 0 if this is the only extent (usually the case). - Only when an attribute 
		                          # list is used does lowest_vcn != 0 ever occur
		'Q',  'last_vcn',         # Highest valid vcn of this extent of the attribute value. - Usually there is 
		                          # only one portion, so this usually equals the attribute value size in clusters 
		                          # minus 1. Can be -1 for zero length files. Can be 0 for "single extent" attributes
		'S',  'mapping_pairs_offset', # Byte offset from the beginning of the structure to the mapping pairs array 
		                              # which contains the mappings between the vcns and the logical cluster numbers (lcns).
                              	  # When creating, place this at the end of this record header aligned to 8-byte boundary.
		'S',  'compression_unit', # The compression unit expressed as the log to the base 2 of the number of
                              # clusters in a compression unit. 0 means not compressed. (This effectively limits the
                              # compression unit size to be a power of two clusters.) WinNT4 only uses a value of 4.
		'L',  nil,                # Align to 8-byte boundary
		
    # The sizes below are only used when lowest_vcn is zero, as otherwise it would
    # be difficult to keep them up-to-date.
		
		'Q',  'allocated_size',   # Byte size of disk space allocated to hold the attribute value. Always is a 
		                          # multiple of the cluster size. When a file is compressed, this field is a 
		                          # multiple of the compression block size (2^compression_unit) and it 
		                          # represents the logically allocated space rather than the actual on disk usage.
		'Q',  'data_size',        # Byte size of the attribute value. 
		                          # Can be larger than allocated_size if attribute value is compressed or sparse
		'Q',  'initialized_size', # Byte size of initialized portion of the attribute value. Usually equals data_size
	])
	# If the attribute is named (name_length is not 0), then the name (in UNICODE) follows here.
	# Here follows the attribute data (if resident) or the data runs (if non-resident).
	SIZEOF_SAH_NONRESIDENT = SAH_NONRESIDENT.size
	
	# One Attribute Header.
	class AttribHeader
		
		attr_reader :name, :type, :typeName, :flags, :id, :length, :specific, :namelen
	  
		AF_COMPRESSED  = 0x0001
		AF_ENCRPYTED   = 0x4000
		AF_SPARSE      = 0x8000
		
		RESIDENT_ATTR_IS_INDEXED = 0x01 # Attribute is referenced in an index 
		                                # (has implications for deleting and modifying the attribute).
		
		# NOTE: All the subordinate objects (attrib header & attributes) take
		#       a buffer (a packed string) starting at the start of the sub object.
		def initialize(buf)
			raise "MIQ(NTFS::AttribHeader.initialize) Nil buffer" if buf.nil?
			
			# Decode standard attribute header.
			@header = STANDARD_ATTRIBUTE_HEADER.decode(buf)
			offset  = SIZEOF_STANDARD_ATTRIBUTE_HEADER

			# If type is AT_END we're done.
			return nil if @header['attrib_type'] == AT_END
	    
			# Get accessor values.
			@length  = @header['length']
			@id      = @header['attrib_id']
			@flags   = @header['flags']
			@type    = @header['attrib_type']
			@namelen = @header['name_length']
	    
			# Get the rest of the data (a resident or non-resident struct).
			which = isResident? ? SAH_RESIDENT        : SAH_NONRESIDENT
			len   = isResident? ? SIZEOF_SAH_RESIDENT : SIZEOF_SAH_NONRESIDENT
			@specific = which.decode(buf[offset..-1])
			offset += len
	    
			# If there's a name get it.
			@name = buf[offset, (@namelen * 2)].UnicodeToUtf8  if @namelen != 0
		end
	  
    def get_value(buf, boot_sector)
      # Prep a buffer to pass to subobjects.
      if isResident?
        # Resident attributes are after header res struct & name.
        abuf = buf[@specific['value_offset'], @specific['value_length']]
      else
        # Nonresident attributes are defined by data runs.
        alen = @specific['data_size']
        alen = buf.size if alen == 0
        abuf = DataRun.new(boot_sector, buf[@specific['mapping_pairs_offset'], alen], self)
      end		  

      return abuf
    end
	  
		# Name will always be something, either name or N/A
		def to_s
			return @name.nil? ? 'N/A' : @name
		end
		
		def isResident?
			@header['non_resident'] == 0
		end
	  
		def typeName
			TypeName[@header['attrib_type']]
		end
		
		def isCompressed?
			NtUtil.gotBit?(@flags, AF_COMPRESSED)
		end
		
		def isEncrypted?
			NtUtil.gotBit?(@flags, AF_ENCRYPTED)
		end
		
		def isSparse?
			NtUtil.gotBit?(@flags, AF_SPARSE)
		end
		
		######################################################################################################
	  # The $I30 is the a "file" name given to NTFS MFT attributes containing file 
	  # name indexes for directories. NTFS stores the file name contents of the 
	  # directory in several places, depending on the number of files in the directory:
    #
    # - For directories with just a few files, all are stored resident in the MFT entry $INDEX_ROOT
    # - For directories with many files, the indexes are stored non-resident in the MFT entry $INDEX_ALLOCATION
    # - The allocation status of these entries are managed by the $BITMAP MFT entry
    #
    # NTFS uses B-tree structures to store and quickly access the data. So, the $INDEX_ROOT attribute 
    # (with a name of $I30) was not large enough to store the B-tree index of file names. Instead, it 
    # points to index records stored in the non-resident $INDEX_ALLOCATION. Viewing the contents of that 
    # file, the B-tree index of file names in the directory.
	  ######################################################################################################
	  def containsFileNameIndexes?
      self.name == "$I30"
    end
		
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Type             : 0x#{'%08x' % @header['attrib_type']} (#{self.typeName})\n"
			out << "  Length           : 0x#{'%08x' % @header['length']}\n"
			out << "  Non resident     : 0x#{'%02x' % @header['non_resident']}\n"
			out << "  Name length      : 0x#{'%02x' % @header['name_length']}\n"
			out << "  Offset to name   : 0x#{'%04x' % @header['name_offset']}\n"
			out << "  Flags            : 0x#{'%04x' % @header['flags']}\n"
			out << "  Attrib id        : 0x#{'%04x' % @header['attrib_id']}\n"
	    
			# Further depends on type.
			if self.isResident?
				out << "  Value length     : 0x#{'%08x' % @specific['value_length']}\n"
				out << "  Value offset     : 0x#{'%04x' % @specific['value_offset']}\n"
				out << "  Resident Flags   : 0x#{'%02x' % @specific['resident_flags']}\n"
			else
				out << "  First VCN        : 0x#{'%016x' % @specific['first_vcn']}\n"
				out << "  Last VCN         : 0x#{'%016x' % @specific['last_vcn']}\n"
				out << "  Mapping Pairs Offset: 0x#{'%04x'  % @specific['mapping_pairs_offset']}\n"
				out << "  Compression      : 0x#{'%04x'  % @specific['compression_unit']}\n"
				out << "  Allocated size   : 0x#{'%016x' % @specific['allocated_size']}\n"
				out << "  Data size        : 0x#{'%016x' % @specific['data_size']}\n"
				out << "  Initialized size : 0x#{'%016x' % @specific['initialized_size']}\n"
			end
			out << "  Name             : #{@name}\n" if @header['name_length'] > 0
			out << "---\n"
		end
	end
end # module NTFS
